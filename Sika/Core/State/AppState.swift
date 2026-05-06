import Foundation
import SwiftUI
import Supabase
import Observation

enum AuthFlow: Equatable {
    case signIn
    case signUp
    case verifyEmail(email: String)
    case authenticatingProfile
    case authenticated(profile: Profile)
}

@Observable
@MainActor
final class AppState {
    // TODO: AppState now manages 7+ fields (flow/profile, accounts, categories,
    // incomeSources, transactions, pendingTransactions, onboardingDismissedThisSession).
    // Approaching the natural limit of a single observable container. Future refactor
    // candidate: split into TransactionStore, AccountStore, etc.
    private(set) var flow: AuthFlow = .signIn
    private(set) var session: Session?
    private(set) var isPerformingAuthAction: Bool = false
    private(set) var lastAuthError: String?
    private(set) var incomeSources: [IncomeSource] = []
    private(set) var accounts: [Account] = []
    private(set) var categories: [TransactionCategory] = []
    private(set) var transactions: [Transaction] = []
    private(set) var pendingTransactions: [Transaction] = []
    private(set) var onboardingDismissedThisSession: Bool = false

    private let authService: AuthService
    private let profileService: ProfileService
    private let incomeService: IncomeService
    private let accountService: AccountService
    private let categoryService: CategoryService
    private let transactionService: TransactionService
    private var authObserverTask: Task<Void, Never>?

    init(
        authService: AuthService = AuthService(),
        profileService: ProfileService = ProfileService(),
        incomeService: IncomeService = IncomeService(),
        accountService: AccountService = AccountService(),
        categoryService: CategoryService = CategoryService(),
        transactionService: TransactionService = TransactionService()
    ) {
        self.authService = authService
        self.profileService = profileService
        self.incomeService = incomeService
        self.accountService = accountService
        self.categoryService = categoryService
        self.transactionService = transactionService
    }

    /// Active currency code from the authenticated profile, or "GHS" as fallback.
    var currencyCode: String {
        guard case .authenticated(let profile) = flow else { return "GHS" }
        return profile.currency
    }

    // MARK: - Optimistic transaction inserts

    /// Insert a row into pendingTransactions immediately for instant UI feedback.
    /// Use UUID() for the temp id; we replace it with the real row when confirmed.
    func addOptimisticTransaction(_ transaction: Transaction) {
        var copy = transaction
        copy.isPending = true
        pendingTransactions.insert(copy, at: 0)
    }

    /// On confirmed Supabase insert, swap the optimistic row for the real row.
    func replaceOptimisticTransaction(tempId: UUID, with persisted: Transaction) {
        pendingTransactions.removeAll { $0.id == tempId }
        transactions.insert(persisted, at: 0)
    }

    /// On Supabase failure, remove the optimistic row.
    func removeOptimisticTransaction(tempId: UUID) {
        pendingTransactions.removeAll { $0.id == tempId }
    }

    var shouldShowOnboarding: Bool {
        guard case .authenticated(let profile) = flow else { return false }
        if onboardingDismissedThisSession { return false }
        let hasIncome = (profile.monthlyIncome ?? 0) > 0
        return !hasIncome && incomeSources.isEmpty
    }

    func dismissOnboardingForSession() {
        onboardingDismissedThisSession = true
    }

    func completeOnboarding(updatedProfile: Profile, sources: [IncomeSource]) {
        self.incomeSources = sources
        if case .authenticated = self.flow {
            self.flow = .authenticated(profile: updatedProfile)
        }
        self.onboardingDismissedThisSession = false
    }

    func bootstrap() async {
        if let session = await authService.currentSession() {
            self.session = session
            self.flow = .authenticatingProfile
            await loadProfile()
        } else {
            self.flow = .signIn
        }
        startObservingAuthChanges()
    }

    private func startObservingAuthChanges() {
        authObserverTask?.cancel()
        authObserverTask = Task { [weak self] in
            guard let self else { return }
            let observerTask = await self.authService.observeAuthChanges { event, session in
                Task { @MainActor [weak self] in
                    await self?.handleAuthChange(event: event, session: session)
                }
            }
            await observerTask.value
        }
    }

    private func handleAuthChange(event: AuthChangeEvent, session: Session?) async {
        switch event {
        case .signedOut:
            self.session = nil
            self.flow = .signIn
        default:
            break
        }
    }

    func goToSignIn() { flow = .signIn; lastAuthError = nil }
    func goToSignUp() { flow = .signUp; lastAuthError = nil }
    func goToVerifyEmail(email: String) { flow = .verifyEmail(email: email); lastAuthError = nil }

    func signIn(email: String, password: String) async {
        lastAuthError = nil
        isPerformingAuthAction = true
        defer { isPerformingAuthAction = false }
        do {
            let session = try await authService.signIn(email: email, password: password)
            self.session = session
            self.flow = .authenticatingProfile
            await loadProfile()
        } catch let error as AuthError {
            if case .emailNotConfirmed = error {
                flow = .verifyEmail(email: email)
                return
            }
            lastAuthError = error.errorDescription
        } catch {
            lastAuthError = error.localizedDescription
        }
    }

    func signUp(email: String, password: String, fullName: String) async {
        lastAuthError = nil
        isPerformingAuthAction = true
        defer { isPerformingAuthAction = false }
        do {
            let result = try await authService.signUp(email: email, password: password, fullName: fullName)
            AnalyticsService.shared.capture(.signedUp)
            switch result {
            case .sessionCreated(let session):
                self.session = session
                self.flow = .authenticatingProfile
                await loadProfile()
            case .verificationRequired(let email):
                flow = .verifyEmail(email: email)
            }
        } catch {
            lastAuthError = error.localizedDescription
        }
    }

    func signOut() async {
        isPerformingAuthAction = true
        defer { isPerformingAuthAction = false }
        do {
            try await authService.signOut()
        } catch {
            print("⚠️ Sign-out remote call failed: \(error.localizedDescription)")
        }
        session = nil
        flow = .signIn
        AnalyticsService.shared.reset()
    }

    func resendVerificationEmail(email: String) async throws {
        try await authService.resendVerificationEmail(email: email)
    }

    private func loadProfile() async {
        let profile: Profile
        do {
            profile = try await profileService.fetchCurrentProfile()
        } catch {
            lastAuthError = "Couldn't load your profile. Please sign in again."
            try? await authService.signOut()
            session = nil
            flow = .signIn
            return
        }

        // Income/accounts/categories/transactions run in parallel and are non-blocking —
        // RLS errors / empty rows shouldn't bounce the user out of auth.
        async let sourcesResult: [IncomeSource] = fetchIncomeSourcesOrEmpty()
        async let accountsResult: [Account] = fetchAccountsOrEmpty()
        async let categoriesResult: [TransactionCategory] = fetchCategoriesOrEmpty()
        async let transactionsResult: [Transaction] = fetchTransactionsOrEmpty()
        let (sources, accounts, categories, transactions) = await
            (sourcesResult, accountsResult, categoriesResult, transactionsResult)

        self.incomeSources = sources
        self.accounts = accounts
        self.categories = categories
        self.transactions = transactions

        flow = .authenticated(profile: profile)

        if let session = self.session {
            AnalyticsService.shared.identify(
                userId: session.user.id.uuidString,
                name: profile.fullName,
                email: session.user.email
            )
            Task { AnalyticsService.shared.reconcileSessionReplay() }
        }
    }

    private func fetchIncomeSourcesOrEmpty() async -> [IncomeSource] {
        do {
            return try await incomeService.fetchAll()
        } catch {
            #if DEBUG
            print("⚠️ Income sources fetch failed (continuing as empty): \(error)")
            #endif
            return []
        }
    }

    private func fetchAccountsOrEmpty() async -> [Account] {
        do {
            return try await accountService.fetchAll()
        } catch {
            #if DEBUG
            print("⚠️ Accounts fetch failed (continuing as empty): \(error)")
            #endif
            return []
        }
    }

    private func fetchCategoriesOrEmpty() async -> [TransactionCategory] {
        do {
            return try await categoryService.fetchAll()
        } catch {
            #if DEBUG
            print("⚠️ Categories fetch failed (continuing as empty): \(error)")
            #endif
            return []
        }
    }

    private func fetchTransactionsOrEmpty() async -> [Transaction] {
        do {
            return try await transactionService.fetchAll()
        } catch {
            #if DEBUG
            print("⚠️ Transactions fetch failed (continuing as empty): \(error)")
            #endif
            return []
        }
    }
}
