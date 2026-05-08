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
    private(set) var goals: [Goal] = []
    private(set) var budgetBuckets: [BudgetBucket] = []
    /// Set of dismissed hint ids (raw strings, mirrors web's array + .includes()).
    /// Stored as Set for O(1) `contains` checks. Populated by loadProfile.
    private(set) var dismissedHints: Set<String> = []
    /// Flips true after the first dismissed_hints fetch resolves (even when
    /// the result is empty). HintCard gates its skeleton placeholder on this
    /// to prevent the flash-then-hide on fresh sign-in.
    private(set) var hintsLoaded: Bool = false
    /// Today's AI-generated insight row (or nil when there's no row, the row
    /// failed to fetch, or the row's dismissed_at is set). Populated by
    /// loadProfile / refreshHomeData.
    private(set) var dailyInsight: DailyInsightRow? = nil
    private(set) var onboardingDismissedThisSession: Bool = false

    /// Cycle navigation: 0 = current cycle, -1 = previous, +1 = next (disallowed
    /// while on current). Per-session state; doesn't persist across launches.
    var cycleOffset: Int = 0

    private let authService: AuthService
    private let profileService: ProfileService
    private let incomeService: IncomeService
    private let accountService: AccountService
    private let categoryService: CategoryService
    private let transactionService: TransactionService
    private let goalService: GoalService
    private let budgetBucketService: BudgetBucketService
    private let dismissedHintService: DismissedHintService
    private let dailyInsightService: DailyInsightService
    private var authObserverTask: Task<Void, Never>?

    init(
        authService: AuthService = AuthService(),
        profileService: ProfileService = ProfileService(),
        incomeService: IncomeService = IncomeService(),
        accountService: AccountService = AccountService(),
        categoryService: CategoryService = CategoryService(),
        transactionService: TransactionService = TransactionService(),
        goalService: GoalService = GoalService(),
        budgetBucketService: BudgetBucketService = BudgetBucketService(),
        dismissedHintService: DismissedHintService = DismissedHintService(),
        dailyInsightService: DailyInsightService = DailyInsightService()
    ) {
        self.authService = authService
        self.profileService = profileService
        self.incomeService = incomeService
        self.accountService = accountService
        self.categoryService = categoryService
        self.transactionService = transactionService
        self.goalService = goalService
        self.budgetBucketService = budgetBucketService
        self.dismissedHintService = dismissedHintService
        self.dailyInsightService = dailyInsightService
    }

    /// Active currency code from the authenticated profile, or "GHS" as fallback.
    var currencyCode: String {
        guard case .authenticated(let profile) = flow else { return "GHS" }
        return profile.currency
    }

    // MARK: - Cycle (Home)

    /// Cycle start day from profile, defaulting to 1 (calendar month) if profile
    /// not loaded or value is invalid (out of 1...28 range to avoid month-clamping
    /// edge cases beyond what CycleCalculator already handles).
    private var profileCycleStartDay: Int {
        if case .authenticated(let profile) = flow {
            let day = profile.cycleStartDay ?? 1
            return (1...31).contains(day) ? day : 1
        }
        return 1
    }

    /// The cycle currently displayed on Home, derived from cycleOffset and the
    /// authenticated profile's cycleStartDay.
    var currentCycle: Cycle {
        CycleCalculator.cycle(
            atOffset: cycleOffset,
            fromDate: Date(),
            cycleStartDay: profileCycleStartDay
        )
    }

    /// Whether the displayed cycle is the present-day one. Drives Right-arrow
    /// disabled state and "Past month" subtitle visibility.
    var isOnCurrentCycle: Bool {
        cycleOffset == 0
    }

    /// Effective monthly income. Sums active income_sources via their
    /// monthlyEquivalent (which already maps weekly→×4.333, biweekly→×2.167);
    /// falls back to profile.monthlyIncome when no active sources exist.
    var monthlyIncomeAmount: Decimal {
        let activeSources = incomeSources.filter { $0.isActive }
        if !activeSources.isEmpty {
            return activeSources.reduce(Decimal(0)) { $0 + $1.monthlyEquivalent }
        }
        if case .authenticated(let profile) = flow {
            return profile.monthlyIncome ?? 0
        }
        return 0
    }

    func goToPreviousCycle() {
        cycleOffset -= 1
    }

    func goToNextCycle() {
        guard !isOnCurrentCycle else { return }
        cycleOffset += 1
    }

    func returnToCurrentCycle() {
        cycleOffset = 0
    }

    /// Re-fetch all Home data sources in parallel (income, accounts, categories,
    /// transactions, goals, budgetBuckets). Profile is intentionally NOT
    /// refetched here — it's stable across a session and full refresh would
    /// risk bouncing the user out on transient profile errors. Called by
    /// pull-to-refresh.
    func refreshHomeData() async {
        guard case .authenticated = flow else { return }

        async let sourcesResult: [IncomeSource] = fetchIncomeSourcesOrEmpty()
        async let accountsResult: [Account] = fetchAccountsOrEmpty()
        async let categoriesResult: [TransactionCategory] = fetchCategoriesOrEmpty()
        async let transactionsResult: [Transaction] = fetchTransactionsOrEmpty()
        async let goalsResult: [Goal] = fetchGoalsOrEmpty()
        async let bucketsResult: [BudgetBucket] = fetchBudgetBucketsOrEmpty()
        async let hintsResult: [String] = fetchDismissedHintsOrEmpty()
        async let insightResult: DailyInsightRow? = fetchDailyInsightOrNil()
        let (sources, accounts, categories, transactions, goals, buckets, hints, insight) = await
            (sourcesResult, accountsResult, categoriesResult, transactionsResult,
             goalsResult, bucketsResult, hintsResult, insightResult)

        self.incomeSources = sources
        self.accounts = accounts
        self.categories = categories
        self.transactions = transactions
        self.goals = goals
        self.budgetBuckets = buckets
        self.dismissedHints = Set(hints)
        self.hintsLoaded = true
        self.dailyInsight = insight
    }

    /// Top 3 active goals by priority for GoalsWidget display.
    var topGoals: [Goal] {
        goals
            .filter { $0.archived != true }
            .sorted { ($0.priority ?? Int.max) < ($1.priority ?? Int.max) }
            .prefix(3)
            .map { $0 }
    }

    /// Transactions whose `transactionDate` (yyyy-MM-dd string) falls within
    /// the currently-displayed cycle window. Lexicographic comparison is
    /// safe for ISO date strings.
    var transactionsInDisplayedCycle: [Transaction] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        let cycle = currentCycle
        let startStr = formatter.string(from: cycle.start)
        let endStr = formatter.string(from: cycle.end)
        return transactions.filter { tx in
            tx.transactionDate >= startStr && tx.transactionDate <= endStr
        }
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

        // Income/accounts/categories/transactions/goals/buckets run in parallel
        // and are non-blocking — RLS errors / empty rows shouldn't bounce the
        // user out of auth.
        async let sourcesResult: [IncomeSource] = fetchIncomeSourcesOrEmpty()
        async let accountsResult: [Account] = fetchAccountsOrEmpty()
        async let categoriesResult: [TransactionCategory] = fetchCategoriesOrEmpty()
        async let transactionsResult: [Transaction] = fetchTransactionsOrEmpty()
        async let goalsResult: [Goal] = fetchGoalsOrEmpty()
        async let bucketsResult: [BudgetBucket] = fetchBudgetBucketsOrEmpty()
        async let hintsResult: [String] = fetchDismissedHintsOrEmpty()
        async let insightResult: DailyInsightRow? = fetchDailyInsightOrNil()
        let (sources, accounts, categories, transactions, goals, buckets, hints, insight) = await
            (sourcesResult, accountsResult, categoriesResult, transactionsResult,
             goalsResult, bucketsResult, hintsResult, insightResult)

        self.incomeSources = sources
        self.accounts = accounts
        self.categories = categories
        self.transactions = transactions
        self.goals = goals
        self.budgetBuckets = buckets
        self.dismissedHints = Set(hints)
        self.hintsLoaded = true
        self.dailyInsight = insight

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

    private func fetchGoalsOrEmpty() async -> [Goal] {
        do {
            return try await goalService.fetchAll()
        } catch {
            #if DEBUG
            print("⚠️ Goals fetch failed (continuing as empty): \(error)")
            #endif
            return []
        }
    }

    private func fetchBudgetBucketsOrEmpty() async -> [BudgetBucket] {
        do {
            return try await budgetBucketService.fetchAll()
        } catch {
            #if DEBUG
            print("⚠️ Budget buckets fetch failed (continuing as empty): \(error)")
            #endif
            return []
        }
    }

    private func fetchDismissedHintsOrEmpty() async -> [String] {
        do {
            return try await dismissedHintService.fetchAll()
        } catch {
            #if DEBUG
            print("⚠️ Dismissed hints fetch failed (continuing as empty): \(error)")
            #endif
            return []
        }
    }

    /// Fetches today's daily_insights row. Returns nil when no row exists,
    /// the fetch failed, or the row is already dismissed (we don't surface
    /// dismissed insights to the view layer).
    private func fetchDailyInsightOrNil() async -> DailyInsightRow? {
        guard let userId = session?.user.id else { return nil }
        do {
            let row = try await dailyInsightService.fetchToday(userId: userId)
            return (row?.dismissedAt == nil) ? row : nil
        } catch {
            #if DEBUG
            print("⚠️ DailyInsight fetch failed (continuing as nil): \(error)")
            #endif
            return nil
        }
    }

    // MARK: - Hint helpers

    /// Whether a given hint has been dismissed.
    /// Returns false until hintsLoaded is true (don't show pre-load).
    func isDismissed(_ hintId: HintId) -> Bool {
        dismissedHints.contains(hintId.rawValue)
    }

    /// Optimistically dismisses a hint. Updates local state immediately,
    /// fires upsert to backend, ignores failures (matches web's no-rollback).
    func dismissHint(_ hintId: HintId) async {
        dismissedHints.insert(hintId.rawValue)
        guard let userId = session?.user.id else { return }
        do {
            try await dismissedHintService.dismiss(userId: userId, hintId: hintId)
        } catch {
            #if DEBUG
            print("⚠️ Dismiss hint upsert failed (silent, matches web): \(error)")
            #endif
        }
    }

    /// Deletes all dismissed hint rows for the user. Wired for a future Settings
    /// "Reset onboarding hints" button — no UI consumer in Phase 4.
    func resetHints() async throws {
        try await dismissedHintService.resetAll()
        dismissedHints.removeAll()
        hintsLoaded = true
    }

    // MARK: - DailyInsight

    /// Optimistically clears today's insight banner. Updates local state
    /// immediately, fires the dismissed_at UPDATE in the background, ignores
    /// failures (matches web's no-rollback pattern).
    /// Wraps the local clear in `withAnimation` so the banner's `.transition`
    /// fires when the conditional unmounts.
    func dismissDailyInsight() async {
        withAnimation(.easeOut(duration: 0.2)) {
            dailyInsight = nil
        }
        guard let userId = session?.user.id else { return }
        do {
            try await dailyInsightService.dismissToday(userId: userId)
        } catch {
            #if DEBUG
            print("⚠️ DailyInsight dismiss failed (silent, matches web): \(error)")
            #endif
        }
    }
}
