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
    /// Latest cycle-end recap that should trigger the banner (viewed_at IS NULL,
    /// dismissed_at IS NULL, generated within last 30 days). Populated by
    /// loadProfile / refreshHomeData.
    private(set) var monthlyRecap: MonthlyRecap? = nil
    /// Today's news digest (shared across all users; no user_id on the row).
    /// Populated by loadProfile / refreshHomeData. Nil when no digest for today.
    private(set) var todayDigest: DailyDigest? = nil
    /// Whether the current user has marked today's digest read. Drives banner
    /// visibility together with `todayDigest`.
    private(set) var digestRead: Bool = false
    /// Income sources due today and not yet dismissed. Populated by phase-2
    /// fetch after the parallel fan-out of secondary data.
    private(set) var incomeNudges: [IncomeNudge] = []
    /// Recurring rules with at least one missed occurrence (auto_log=false).
    /// Income-typed rules are filtered at the view boundary via
    /// `visiblePendingRecurring`.
    private(set) var pendingRecurring: [PendingRecurring] = []

    // MARK: - Phase Accounts T1 — derived balances

    /// account.id → derived balance, computed via AccountBalanceEngine.
    /// Recomputed after any account or transaction mutation.
    private(set) var accountsBalances: [UUID: Decimal] = [:]
    /// Once-per-session guard for the auto_log=true silent generation pass.
    /// Mirrors web's useRef-based "have we run this yet" check.
    private var hasGeneratedThisSession: Bool = false
    private(set) var onboardingDismissedThisSession: Bool = false

    // MARK: - Recurring tab state

    enum RecurringTab: String, CaseIterable, Identifiable {
        case expense, paused
        var id: String { rawValue }
    }

    /// All active recurrings (joined account + category) for the user.
    /// Tab segmentation is computed client-side via `expenseRecurrings` /
    /// `pausedRecurrings`.
    private(set) var recurringList: [RecurringTransaction] = []
    var recurringTab: RecurringTab = .expense
    private(set) var recurringLoading: Bool = false
    private(set) var recurringSyncing: Bool = false

    // MARK: - Phase 9 (gamification)

    /// Composed health snapshot (score + streaks + momentum + badges).
    /// Loaded on profile load + refresh; refreshed after every mutation
    /// that affects score inputs.
    private(set) var healthSnapshot: HealthSnapshot? = nil

    /// Queue of badge unlocks awaiting the celebration sheet. Populated on
    /// profile load (cross-platform handoff) and after mutation hooks
    /// surface new unlocks. Head of the array drives the .fullScreenCover.
    private(set) var unviewedBadgeUnlocks: [UserBadge] = []

    // MARK: - Phase T1 (Transactions tab)

    /// Joined transaction rows for the Transactions tab list.
    /// Distinct from `transactions` (the simple array used by Home/scoring).
    private(set) var transactionsList: [TransactionListRow] = []
    var transactionFilters = TransactionFilters()
    private(set) var transactionsPage: Int = 0
    private(set) var transactionsHasMore: Bool = false
    private(set) var transactionsTotalCount: Int = 0
    private(set) var transactionsLoading: Bool = false
    private(set) var transactionsLoadingMore: Bool = false

    // MARK: - Goals tab state (Phase Goals T1)

    /// Composed goal-progress snapshots for the Goals tab. Keyed by goal id.
    /// `goalsList` holds the raw goals; `goalsProgressMap` holds the
    /// derived currentAmount + pace + status. Both refresh together via
    /// `loadGoalsList()`.
    private(set) var goalsList: [Goal] = []
    private(set) var goalsProgressMap: [UUID: GoalProgress] = [:]
    private(set) var goalsLoading: Bool = false

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
    private let recurringService: RecurringService
    private let incomeNudgeService: IncomeNudgeService
    private let monthlyRecapService: MonthlyRecapService
    private let sikaDailyService: SikaDailyService
    private let healthService: HealthService
    private let streakService: StreakService
    private let momentumService: MomentumService
    private let badgeService: BadgeService
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
        dailyInsightService: DailyInsightService = DailyInsightService(),
        recurringService: RecurringService = RecurringService(),
        incomeNudgeService: IncomeNudgeService = IncomeNudgeService(),
        monthlyRecapService: MonthlyRecapService = MonthlyRecapService(),
        sikaDailyService: SikaDailyService = SikaDailyService(),
        healthService: HealthService = HealthService(),
        streakService: StreakService = StreakService(),
        momentumService: MomentumService = MomentumService(),
        badgeService: BadgeService = BadgeService()
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
        self.recurringService = recurringService
        self.incomeNudgeService = incomeNudgeService
        self.monthlyRecapService = monthlyRecapService
        self.sikaDailyService = sikaDailyService
        self.healthService = healthService
        self.streakService = streakService
        self.momentumService = momentumService
        self.badgeService = badgeService
    }

    /// Active currency code from the authenticated profile, or "GHS" as fallback.
    var currencyCode: String {
        guard case .authenticated(let profile) = flow else { return "GHS" }
        return profile.currency
    }

    /// Active card theme from the authenticated profile, with `.sankofa`
    /// fallback when the profile string is missing or unrecognized.
    /// Drives CycleCard rendering on Home + the live preview in Settings.
    var cardTheme: HeritageCardTheme {
        guard case .authenticated(let profile) = flow,
              let theme = HeritageCardTheme(rawValue: profile.cardTheme) else {
            return .sankofa
        }
        return theme
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
        async let recapResult: MonthlyRecap? = fetchMonthlyRecapOrNil()
        async let digestResult: (DailyDigest?, Bool) = fetchDigestAndReadState()
        let (sources, accounts, categories, transactions, goals, buckets, hints, insight, recap, digestPair) = await
            (sourcesResult, accountsResult, categoriesResult, transactionsResult,
             goalsResult, bucketsResult, hintsResult, insightResult, recapResult, digestResult)

        self.incomeSources = sources
        self.accounts = accounts
        self.categories = categories
        self.transactions = transactions
        self.goals = goals
        self.budgetBuckets = buckets
        self.dismissedHints = Set(hints)
        self.hintsLoaded = true
        self.dailyInsight = insight
        self.monthlyRecap = recap
        self.todayDigest = digestPair.0
        self.digestRead = digestPair.1

        await loadNudgesAndRecurring()
        await loadHealthSnapshot()
    }

    /// Phase-2 loader for income nudges + recurring auto-log + pending.
    /// Runs sequentially after the main parallel batch because it depends on
    /// `incomeSources` being populated and the once-per-session guard.
    private func loadNudgesAndRecurring() async {
        guard let userId = session?.user.id else { return }

        self.incomeNudges = await fetchIncomeNudgesOrEmpty(
            userId: userId,
            sources: incomeSources
        )

        if !hasGeneratedThisSession {
            self.pendingRecurring = await generateRecurringOrEmpty(userId: userId)
            self.hasGeneratedThisSession = true
        }
        // After the once-per-session guard fires, we leave pendingRecurring
        // alone on subsequent refreshes — confirm/skip mutate it directly.
    }

    private func fetchIncomeNudgesOrEmpty(userId: UUID, sources: [IncomeSource]) async -> [IncomeNudge] {
        guard !sources.isEmpty else { return [] }
        do {
            return try await incomeNudgeService.dueNudges(userId: userId, sources: sources)
        } catch {
            #if DEBUG
            print("⚠️ Income nudges fetch failed (continuing as empty): \(error)")
            #endif
            return []
        }
    }

    private func generateRecurringOrEmpty(userId: UUID) async -> [PendingRecurring] {
        do {
            return try await recurringService.generateAndCollectPending(userId: userId)
        } catch {
            #if DEBUG
            print("⚠️ Recurring generation failed (continuing as empty): \(error)")
            #endif
            return []
        }
    }

    /// Top 3 active goals by priority for GoalsWidget display.
    var topGoals: [Goal] {
        goals
            .filter { $0.isArchived != true }
            .sorted { ($0.priority ?? Int.max) < ($1.priority ?? Int.max) }
            .prefix(3)
            .map { $0 }
    }

    /// Pending recurring rules visible on Home. Income-typed rules are
    /// filtered out per web's legacy-data hygiene (income comes from
    /// income_sources, not recurring_transactions).
    var visiblePendingRecurring: [PendingRecurring] {
        pendingRecurring.filter { $0.recurring.type != .income }
    }

    /// Whether the DailyDigestBanner should render on Home.
    /// Mirrors web's `digest && !isRead` predicate.
    var shouldShowDailyDigestBanner: Bool {
        todayDigest != nil && !digestRead
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
        async let recapResult: MonthlyRecap? = fetchMonthlyRecapOrNil()
        async let digestResult: (DailyDigest?, Bool) = fetchDigestAndReadState()
        let (sources, accounts, categories, transactions, goals, buckets, hints, insight, recap, digestPair) = await
            (sourcesResult, accountsResult, categoriesResult, transactionsResult,
             goalsResult, bucketsResult, hintsResult, insightResult, recapResult, digestResult)

        self.incomeSources = sources
        self.accounts = accounts
        self.categories = categories
        self.transactions = transactions
        self.goals = goals
        self.budgetBuckets = buckets
        self.dismissedHints = Set(hints)
        self.hintsLoaded = true
        self.dailyInsight = insight
        self.monthlyRecap = recap
        self.todayDigest = digestPair.0
        self.digestRead = digestPair.1

        await loadNudgesAndRecurring()
        await loadHealthSnapshot()
        await fireCycleEndedBadgeCheck()

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

    /// Fetches the latest monthly_recaps row that satisfies the banner-trigger
    /// predicate (viewed/dismissed null + generated within last 30 days).
    /// Returns nil if no eligible row, fetch failed, or filters excluded all rows.
    private func fetchMonthlyRecapOrNil() async -> MonthlyRecap? {
        do {
            return try await monthlyRecapService.fetchLatestForBanner()
        } catch {
            #if DEBUG
            print("⚠️ MonthlyRecap fetch failed (continuing as nil): \(error)")
            #endif
            return nil
        }
    }

    /// Fetches today's digest row + the user's read marker as a tuple.
    /// Returns (nil, false) when no digest exists or fetch fails.
    /// Returns (digest, true) when user has already marked it read.
    /// Returns (digest, false) when digest exists but unread.
    private func fetchDigestAndReadState() async -> (DailyDigest?, Bool) {
        guard let userId = session?.user.id else { return (nil, false) }
        do {
            guard let digest = try await sikaDailyService.fetchTodayDigest() else {
                return (nil, false)
            }
            let read = (try? await sikaDailyService.hasReadToday(
                userId: userId,
                digestDate: digest.digestDate
            )) ?? false
            return (digest, read)
        } catch {
            #if DEBUG
            print("⚠️ DailyDigest fetch failed (continuing as nil): \(error)")
            #endif
            return (nil, false)
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

    // MARK: - Income nudges

    /// "Yes, log it" on income nudge: insert a transaction and record the
    /// dismissal as `.logged`. Uses the user's default account
    /// (account.isDefault == true), falling back to the first account.
    /// Silently no-ops when no account exists (toast UI not shipped yet).
    func logIncomeNudge(_ nudge: IncomeNudge) async {
        guard let userId = session?.user.id else { return }
        guard let account = accounts.first(where: { $0.isDefault == true })
            ?? accounts.first else {
            #if DEBUG
            print("⚠️ logIncomeNudge: no account available; cannot insert")
            #endif
            return
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        let today = formatter.string(from: Date())

        let draft = TransactionDraft(
            userId: userId,
            type: .income,
            amount: nudge.incomeSource.amount,
            accountId: account.id,
            toAccountId: nil,
            categoryId: nil,
            transactionDate: today,
            note: nudge.incomeSource.name,
            isActive: true
        )

        do {
            _ = try await transactionService.insert(draft)
            try await incomeNudgeService.recordDismissal(
                userId: userId,
                sourceId: nudge.incomeSource.id,
                dueDate: nudge.dueDate,
                action: .logged
            )
            withAnimation(.easeOut(duration: 0.2)) {
                incomeNudges.removeAll { $0.id == nudge.id }
            }
            await refreshHomeData()
            // Phase 9: streak/momentum/badge hooks. Fire-and-forget.
            Task { await fireTransactionLoggedHooks() }
        } catch {
            #if DEBUG
            print("⚠️ logIncomeNudge failed: \(error)")
            #endif
        }
    }

    /// "Not yet" on income nudge — same suppression effect as dismiss, but
    /// recorded with `action = .snoozed` so analytics can distinguish.
    func snoozeIncomeNudge(_ nudge: IncomeNudge) async {
        guard let userId = session?.user.id else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            incomeNudges.removeAll { $0.id == nudge.id }
        }
        do {
            try await incomeNudgeService.recordDismissal(
                userId: userId,
                sourceId: nudge.incomeSource.id,
                dueDate: nudge.dueDate,
                action: .snoozed
            )
        } catch {
            #if DEBUG
            print("⚠️ snoozeIncomeNudge failed (silent): \(error)")
            #endif
        }
    }

    /// X dismiss on income nudge.
    func dismissIncomeNudge(_ nudge: IncomeNudge) async {
        guard let userId = session?.user.id else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            incomeNudges.removeAll { $0.id == nudge.id }
        }
        do {
            try await incomeNudgeService.recordDismissal(
                userId: userId,
                sourceId: nudge.incomeSource.id,
                dueDate: nudge.dueDate,
                action: .dismissed
            )
        } catch {
            #if DEBUG
            print("⚠️ dismissIncomeNudge failed (silent): \(error)")
            #endif
        }
    }

    // MARK: - Pending recurring

    /// "Log it" on a pending recurring: insert a transaction at the latest
    /// missed due date and bump last_generated_date. Optimistic local removal.
    func confirmPendingRecurring(_ pending: PendingRecurring) async {
        guard let userId = session?.user.id else { return }
        guard let dueDate = pending.latestDueDate else { return }

        withAnimation(.easeOut(duration: 0.2)) {
            pendingRecurring.removeAll { $0.id == pending.id }
        }

        do {
            try await recurringService.confirmPending(
                userId: userId,
                recurring: pending.recurring,
                dueDate: dueDate
            )
            await refreshHomeData()
            // Phase 9: streak/momentum/badge hooks. Fire-and-forget.
            Task { await fireTransactionLoggedHooks() }
        } catch {
            #if DEBUG
            print("⚠️ confirmPendingRecurring failed: \(error)")
            #endif
        }
    }

    /// "Skip" on a pending recurring: just bump last_generated_date.
    func skipPendingRecurring(_ pending: PendingRecurring) async {
        guard let dueDate = pending.latestDueDate else { return }

        withAnimation(.easeOut(duration: 0.2)) {
            pendingRecurring.removeAll { $0.id == pending.id }
        }

        do {
            try await recurringService.skipPending(
                recurringId: pending.recurring.id,
                dueDate: dueDate
            )
        } catch {
            #if DEBUG
            print("⚠️ skipPendingRecurring failed (silent): \(error)")
            #endif
        }
    }

    // MARK: - MonthlyRecap

    /// X dismiss on the monthly recap banner. Sets dismissed_at on the row;
    /// banner stays gone for THIS recap but next cycle's row is independent.
    /// Optimistic local clear; failures silently logged in DEBUG.
    func dismissMonthlyRecap() async {
        guard let recap = monthlyRecap else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            monthlyRecap = nil
        }
        do {
            try await monthlyRecapService.dismiss(recapId: recap.id)
        } catch {
            #if DEBUG
            print("⚠️ dismissMonthlyRecap failed (silent): \(error)")
            #endif
        }
    }

    /// Mark the recap as viewed (called from MonthlyRecapDetailView's
    /// onAppear, guarded once per detail view instance).
    /// Hides banner permanently for this recap — clears AppState.monthlyRecap
    /// if it matches so navigating back to Home shows no banner.
    func markMonthlyRecapViewed(recapId: UUID) async {
        if monthlyRecap?.id == recapId {
            monthlyRecap = nil
        }
        do {
            try await monthlyRecapService.markViewed(recapId: recapId)
        } catch {
            #if DEBUG
            print("⚠️ markMonthlyRecapViewed failed (silent): \(error)")
            #endif
        }
    }

    /// Mark the recap as shared (analytics-only; doesn't affect banner visibility).
    func markMonthlyRecapShared(recapId: UUID) async {
        do {
            try await monthlyRecapService.markShared(recapId: recapId)
        } catch {
            #if DEBUG
            print("⚠️ markMonthlyRecapShared failed (silent): \(error)")
            #endif
        }
    }

    // MARK: - DailyDigest

    /// Marks today's digest as read. Optimistic local update + idempotent
    /// insert to user_daily_reads. No-op if already read or no digest loaded.
    /// Wraps the local flip in `withAnimation` so the banner's transition
    /// fires when shouldShowDailyDigestBanner flips false.
    func markDigestRead() async {
        guard let digest = todayDigest, !digestRead else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            digestRead = true
        }
        guard let userId = session?.user.id else { return }
        await sikaDailyService.markRead(
            userId: userId,
            digestDate: digest.digestDate
        )
    }

    // MARK: - Card theme (Phase 6)

    /// Updates the user's card theme. Optimistic local update + Supabase
    /// write + rollback on error. Profile fields are `let`, so the optimistic
    /// path constructs a new Profile via `withCardTheme` and replaces the
    /// `.authenticated` flow case.
    func updateCardTheme(_ theme: HeritageCardTheme) async {
        guard case .authenticated(let profile) = flow else { return }
        let previousValue = profile.cardTheme

        // Optimistic local update.
        withAnimation(.easeOut(duration: 0.2)) {
            self.flow = .authenticated(profile: profile.withCardTheme(theme.rawValue))
        }

        guard let userId = session?.user.id else { return }

        struct Payload: Encodable { let card_theme: String }

        do {
            try await SupabaseManager.shared.client
                .from("profiles")
                .update(Payload(card_theme: theme.rawValue))
                .eq("id", value: userId)
                .execute()
        } catch {
            // Rollback to previous value.
            if case .authenticated(let current) = flow {
                self.flow = .authenticated(profile: current.withCardTheme(previousValue))
            }
            #if DEBUG
            print("⚠️ updateCardTheme failed (rolled back): \(error)")
            #endif
        }
    }

    // MARK: - Phase 9 (gamification) — load + hooks

    /// Whether the user has logged a transaction today. Drives HealthRow's
    /// streak-chip pulse — pulses while loggingCurrent > 0 AND not yet
    /// logged today.
    var hasLoggedToday: Bool {
        StreakEngine.hasLoggedToday(healthSnapshot?.streaks)
    }

    /// Loads the composed health snapshot. Side-effects:
    /// - Populates `healthSnapshot`
    /// - Enqueues any user_badges with celebration_shown=false
    ///   (cross-platform handoff: badges unlocked on web auto-celebrate
    ///    on the next iOS load)
    private func loadHealthSnapshot() async {
        guard let userId = session?.user.id else { return }
        let snapshot = await healthService.fetchSnapshot(
            userId: userId,
            categories: categories,
            budgetBuckets: budgetBuckets
        )
        self.healthSnapshot = snapshot

        let pending = snapshot.userBadges
            .filter { !$0.celebrationShown }
            .sorted { $0.unlockedAt < $1.unlockedAt }
        // Merge into queue without dropping anything already enqueued
        for unlock in pending where !unviewedBadgeUnlocks.contains(where: { $0.id == unlock.id }) {
            unviewedBadgeUnlocks.append(unlock)
        }
    }

    /// On profile load, evaluate the cycle_ended trigger (safety_net check).
    /// Mirror of web's dashboard-mount useEffect.
    private func fireCycleEndedBadgeCheck() async {
        guard let userId = session?.user.id else { return }
        let unlocked = await badgeService.checkAndUnlock(userId: userId, trigger: .cycleEnded)
        for badge in unlocked where !unviewedBadgeUnlocks.contains(where: { $0.id == badge.id }) {
            unviewedBadgeUnlocks.append(badge)
        }
    }

    /// Refresh the snapshot after a mutation. Called by mutation hooks.
    /// Best-effort; on auth loss the snapshot stays stale.
    func refreshHealthSnapshot() async {
        await loadHealthSnapshot()
    }

    /// Mutation hook for user-initiated transaction creation.
    /// Fires:
    /// - logging streak update
    /// - momentum: transaction_logged (+2) [+ logging_streak_7_days bonus on milestone]
    /// - badge checks: transaction_logged + streak_updated
    /// - snapshot refresh
    ///
    /// Fire-and-forget: never throws, never blocks the caller.
    /// Auto-generated recurring transactions DO NOT call this — matches web.
    func fireTransactionLoggedHooks() async {
        guard let userId = session?.user.id else { return }

        let streakResult = await streakService.updateLoggingStreak(userId: userId)
        await momentumService.award(userId: userId, event: .transactionLogged)

        if streakResult?.milestoneHit == 7 {
            await momentumService.award(userId: userId, event: .loggingStreak7Days)
        }

        async let txnUnlocks = badgeService.checkAndUnlock(userId: userId, trigger: .transactionLogged)
        async let streakUnlocks = streakResult != nil
            ? badgeService.checkAndUnlock(userId: userId, trigger: .streakUpdated)
            : []

        let (txnNew, streakNew) = await (txnUnlocks, streakUnlocks)
        for badge in txnNew + streakNew where !unviewedBadgeUnlocks.contains(where: { $0.id == badge.id }) {
            unviewedBadgeUnlocks.append(badge)
        }

        await loadHealthSnapshot()
    }

    /// Dismiss the head of the celebration queue. Persists celebration_shown=true.
    func dismissBadgeCelebration(_ badge: UserBadge) async {
        unviewedBadgeUnlocks.removeAll { $0.id == badge.id }
        await badgeService.markCelebrationShown(userBadgeId: badge.id)
    }

    // MARK: - Recurring tab — segments + actions

    /// Active expense recurrings, sorted by next due date asc.
    var expenseRecurrings: [RecurringTransaction] {
        recurringList
            .filter { $0.type == .expense && !$0.isPaused }
            .sorted { lhs, rhs in
                let a = RecurringDateMath.nextDueDate(for: lhs, from: Date())?.timeIntervalSince1970 ?? .infinity
                let b = RecurringDateMath.nextDueDate(for: rhs, from: Date())?.timeIntervalSince1970 ?? .infinity
                return a < b
            }
    }

    /// All paused recurrings (any type), most-recently-updated first.
    var pausedRecurrings: [RecurringTransaction] {
        recurringList
            .filter { $0.isPaused }
            .sorted { ($0.updatedAt ?? Date.distantPast) > ($1.updatedAt ?? Date.distantPast) }
    }

    /// Load all recurrings (joined fetch).
    func loadRecurrings() async {
        guard let userId = session?.user.id else { return }
        recurringLoading = true
        do {
            recurringList = try await recurringService.fetchAll(userId: userId)
        } catch {
            #if DEBUG
            print("⚠️ loadRecurrings failed: \(error)")
            #endif
            recurringList = []
        }
        recurringLoading = false
    }

    /// Optimistic pause/resume. Reverts the in-memory flag on error so the UI
    /// stays consistent with the server.
    func togglePaused(_ recurring: RecurringTransaction) async {
        let newValue = !recurring.isPaused
        // Optimistic
        if let idx = recurringList.firstIndex(where: { $0.id == recurring.id }) {
            recurringList[idx] = recurringWith(recurringList[idx], isPaused: newValue)
        }
        do {
            try await recurringService.setPaused(id: recurring.id, isPaused: newValue)
        } catch {
            // Revert
            if let idx = recurringList.firstIndex(where: { $0.id == recurring.id }) {
                recurringList[idx] = recurringWith(recurringList[idx], isPaused: recurring.isPaused)
            }
            #if DEBUG
            print("⚠️ togglePaused failed: \(error)")
            #endif
        }
    }

    /// Soft delete. Caller should drive the confirmation alert; this method
    /// just performs the write + local removal.
    @discardableResult
    func deleteRecurring(_ id: UUID) async -> Bool {
        do {
            try await recurringService.softDelete(id: id)
            recurringList.removeAll { $0.id == id }
            return true
        } catch {
            #if DEBUG
            print("⚠️ deleteRecurring failed: \(error)")
            #endif
            return false
        }
    }

    /// Manual sync trigger. Spins the icon while running; reloads on success.
    func syncRecurringNow() async {
        guard let userId = session?.user.id else { return }
        recurringSyncing = true
        do {
            try await recurringService.syncNow(userId: userId)
            await loadRecurrings()
        } catch {
            #if DEBUG
            print("⚠️ syncRecurringNow failed: \(error)")
            #endif
        }
        recurringSyncing = false
    }

    /// Detail-page "Log this instance now". No mutation hooks fire here.
    @discardableResult
    func logRecurringInstanceNow(
        _ recurring: RecurringTransaction,
        dueDate: String
    ) async -> Bool {
        guard let userId = session?.user.id else { return false }
        do {
            try await recurringService.logInstanceNow(
                userId: userId,
                recurring: recurring,
                dueDate: dueDate
            )
            await loadRecurrings()
            return true
        } catch {
            #if DEBUG
            print("⚠️ logRecurringInstanceNow failed: \(error)")
            #endif
            return false
        }
    }

    /// Detail-page "Skip this period".
    @discardableResult
    func skipRecurringPeriod(
        _ recurring: RecurringTransaction,
        dueDate: String
    ) async -> Bool {
        do {
            try await recurringService.skipPeriod(recurringId: recurring.id, dueDate: dueDate)
            await loadRecurrings()
            return true
        } catch {
            #if DEBUG
            print("⚠️ skipRecurringPeriod failed: \(error)")
            #endif
            return false
        }
    }

    /// Reload after a form-sheet save (create or update).
    func reloadRecurringsAfterFormSave() async {
        await loadRecurrings()
    }

    /// Constructs a copy of a RecurringTransaction with a single field flipped.
    /// All struct fields are `let`, so we rebuild via the synthesized memberwise init.
    private func recurringWith(_ rec: RecurringTransaction, isPaused: Bool) -> RecurringTransaction {
        RecurringTransaction(
            id: rec.id,
            userId: rec.userId,
            accountId: rec.accountId,
            categoryId: rec.categoryId,
            type: rec.type,
            amount: rec.amount,
            note: rec.note,
            frequency: rec.frequency,
            startDate: rec.startDate,
            endDate: rec.endDate,
            scheduleDay: rec.scheduleDay,
            autoLog: rec.autoLog,
            lastGeneratedDate: rec.lastGeneratedDate,
            isActive: rec.isActive,
            isPaused: isPaused,
            createdAt: rec.createdAt,
            updatedAt: rec.updatedAt,
            account: rec.account,
            category: rec.category
        )
    }

    // MARK: - Phase S1 (Settings) — actions

    /// Sum of monthlyEquivalent across active income sources. Used by
    /// the Budget Split GHS preview and Total Monthly Income echo card.
    var totalMonthlyIncomeComputed: Decimal {
        incomeSources.filter(\.isActive)
            .reduce(Decimal(0)) { $0 + $1.monthlyEquivalent }
    }

    /// Apply the given theme to the active UIWindow.
    /// Affects every view immediately. Called both on theme change and
    /// once at app launch (via RootView's onAppear).
    func applySystemTheme(_ theme: SystemTheme) {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        for window in scene.windows {
            window.overrideUserInterfaceStyle = theme.uiUserInterfaceStyle
        }
    }

    /// Optimistic theme update. Applies to UIWindow + persists via HTTP/Bearer.
    func updateSystemTheme(_ theme: SystemTheme) async {
        guard case .authenticated(let profile) = flow else { return }
        let previous = profile.themePreference

        withAnimation(.easeOut(duration: 0.2)) {
            self.flow = .authenticated(profile: profile.withThemePreference(theme.rawValue))
        }
        applySystemTheme(theme)

        do {
            try await profileService.updateTheme(theme)
        } catch {
            #if DEBUG
            print("⚠️ updateSystemTheme failed (rolled back): \(error)")
            #endif
            if case .authenticated(let current) = flow {
                self.flow = .authenticated(profile: current.withThemePreference(previous))
                if let restored = SystemTheme(rawValue: previous) {
                    applySystemTheme(restored)
                }
            }
        }
    }

    /// Optimistic haptics toggle. Persists via HTTP/Bearer.
    func updateHapticsEnabled(_ enabled: Bool) async {
        guard case .authenticated(let profile) = flow else { return }
        let previous = profile.hapticsEnabled

        self.flow = .authenticated(profile: profile.withHapticsEnabled(enabled))

        do {
            try await profileService.updateHaptics(enabled)
        } catch {
            #if DEBUG
            print("⚠️ updateHapticsEnabled failed (rolled back): \(error)")
            #endif
            if case .authenticated(let current) = flow {
                self.flow = .authenticated(profile: current.withHapticsEnabled(previous ?? true))
            }
        }
    }

    /// Update currency. Non-optimistic — caller awaits the round-trip.
    /// Returns true on success.
    @discardableResult
    func updateCurrency(_ code: String) async -> Bool {
        guard case .authenticated(let profile) = flow else { return false }
        do {
            try await profileService.updateCurrency(code)
            self.flow = .authenticated(profile: profile.withCurrency(code))
            return true
        } catch {
            #if DEBUG
            print("⚠️ updateCurrency failed: \(error)")
            #endif
            return false
        }
    }

    /// Save Budget Month + Budget Split together. Direct Supabase write.
    /// Caller is responsible for sum-validates-100 guard at the form layer.
    @discardableResult
    func saveBudgetConfig(
        cycleStartDay: Int,
        needsPercent: Decimal,
        wantsPercent: Decimal,
        savingsPercent: Decimal
    ) async -> Bool {
        guard case .authenticated(let profile) = flow else { return false }
        guard let userId = session?.user.id else { return false }
        do {
            try await profileService.updateBudgetConfig(
                userId: userId,
                cycleStartDay: cycleStartDay,
                needsPercent: needsPercent,
                wantsPercent: wantsPercent,
                savingsPercent: savingsPercent
            )
            self.flow = .authenticated(profile: profile.withBudgetConfig(
                cycleStartDay: cycleStartDay,
                needsPercent: needsPercent,
                wantsPercent: wantsPercent,
                savingsPercent: savingsPercent
            ))
            return true
        } catch {
            #if DEBUG
            print("⚠️ saveBudgetConfig failed: \(error)")
            #endif
            return false
        }
    }

    /// Hard-deletes the user account via the cascade endpoint. Returns true
    /// on success — caller should follow with sign-out flow.
    @discardableResult
    func deleteAccount() async -> Bool {
        do {
            try await profileService.deleteAccount()
            // Server-side cascade kills the auth user; signOut clears local.
            try? await authService.signOut()
            self.session = nil
            self.flow = .signIn
            return true
        } catch {
            #if DEBUG
            print("⚠️ deleteAccount failed: \(error)")
            #endif
            return false
        }
    }

    // MARK: - Phase S2 (Settings → Income Sources) — CRUD + syncMonthlyIncome

    /// Create a new income source. After the row is inserted, fires
    /// `syncMonthlyIncome` so `profiles.monthly_income` (and the local
    /// `profile.monthlyIncome` cache) reflect the new aggregate.
    /// Phase 9's HealthRow reads this field — the sync is mandatory.
    @discardableResult
    func createIncomeSource(
        name: String,
        amount: Decimal,
        frequency: IncomeFrequency,
        expectedDay: Int?,
        icon: String?,
        accountId: UUID?,
        isActive: Bool = true
    ) async -> Bool {
        guard let userId = session?.user.id else { return false }
        do {
            let payload = IncomeService.IncomeSourcePayload(
                user_id: userId,
                name: name,
                amount: amount,
                frequency: frequency.rawValue,
                expected_day: expectedDay,
                icon: icon,
                account_id: accountId,
                is_active: isActive
            )
            let row = try await incomeService.create(payload: payload)
            incomeSources.append(row)
            try await incomeService.syncMonthlyIncome(userId: userId, sources: incomeSources)
            syncLocalProfileMonthlyIncome()
            return true
        } catch {
            #if DEBUG
            print("⚠️ createIncomeSource failed: \(error)")
            #endif
            return false
        }
    }

    /// Update an existing income source. Fires `syncMonthlyIncome` on success.
    @discardableResult
    func updateIncomeSource(
        id: UUID,
        name: String,
        amount: Decimal,
        frequency: IncomeFrequency,
        expectedDay: Int?,
        icon: String?,
        accountId: UUID?,
        isActive: Bool
    ) async -> Bool {
        guard let userId = session?.user.id else { return false }
        do {
            let payload = IncomeService.IncomeSourcePayload(
                user_id: userId,
                name: name,
                amount: amount,
                frequency: frequency.rawValue,
                expected_day: expectedDay,
                icon: icon,
                account_id: accountId,
                is_active: isActive
            )
            let row = try await incomeService.update(id: id, payload: payload)
            if let idx = incomeSources.firstIndex(where: { $0.id == id }) {
                incomeSources[idx] = row
            }
            try await incomeService.syncMonthlyIncome(userId: userId, sources: incomeSources)
            syncLocalProfileMonthlyIncome()
            return true
        } catch {
            #if DEBUG
            print("⚠️ updateIncomeSource failed: \(error)")
            #endif
            return false
        }
    }

    /// Hard delete an income source. Fires `syncMonthlyIncome` on success.
    @discardableResult
    func deleteIncomeSource(_ id: UUID) async -> Bool {
        guard let userId = session?.user.id else { return false }
        do {
            try await incomeService.delete(id: id)
            incomeSources.removeAll { $0.id == id }
            try await incomeService.syncMonthlyIncome(userId: userId, sources: incomeSources)
            syncLocalProfileMonthlyIncome()
            return true
        } catch {
            #if DEBUG
            print("⚠️ deleteIncomeSource failed: \(error)")
            #endif
            return false
        }
    }

    /// Recompute the aggregate from `incomeSources` and stamp the result onto
    /// the local profile cache. Called after a successful `syncMonthlyIncome`
    /// so the UI reflects the new monthly income without a profile refetch.
    private func syncLocalProfileMonthlyIncome() {
        guard case .authenticated(let profile) = flow else { return }
        let total = incomeSources.filter(\.isActive)
            .reduce(Decimal(0)) { $0 + $1.monthlyEquivalent }
        flow = .authenticated(profile: profile.withMonthlyIncome(total))
    }

    // MARK: - Phase T1 (Transactions tab) — load + delete

    /// Load the first page of transactions with current filters.
    /// Resets pagination state.
    func loadFirstTransactionsPage() async {
        guard let userId = session?.user.id else { return }
        transactionsLoading = true
        transactionsPage = 0
        do {
            let result = try await transactionService.fetchPage(
                userId: userId,
                filters: transactionFilters,
                cycleStartDay: profileCycleStartDay,
                page: 0
            )
            transactionsList = result.rows
            transactionsTotalCount = result.totalCount
            transactionsHasMore = transactionsList.count < result.totalCount
        } catch {
            #if DEBUG
            print("⚠️ loadFirstTransactionsPage failed: \(error)")
            #endif
            transactionsList = []
            transactionsHasMore = false
            transactionsTotalCount = 0
        }
        transactionsLoading = false
    }

    /// Load the next page (manual "Load more" button).
    func loadMoreTransactions() async {
        guard !transactionsLoadingMore, transactionsHasMore else { return }
        guard let userId = session?.user.id else { return }
        transactionsLoadingMore = true
        let nextPage = transactionsPage + 1
        do {
            let result = try await transactionService.fetchPage(
                userId: userId,
                filters: transactionFilters,
                cycleStartDay: profileCycleStartDay,
                page: nextPage
            )
            transactionsList.append(contentsOf: result.rows)
            transactionsTotalCount = result.totalCount
            transactionsHasMore = transactionsList.count < result.totalCount
            transactionsPage = nextPage
        } catch {
            #if DEBUG
            print("⚠️ loadMoreTransactions failed: \(error)")
            #endif
        }
        transactionsLoadingMore = false
    }

    /// Hard delete a transaction. Removes from the local list optimistically
    /// (with animation) and reconciles the count. No undo. Mirror of web's
    /// confirm-then-delete + revalidate flow.
    @discardableResult
    func deleteTransactionFromList(_ id: UUID) async -> Bool {
        do {
            try await transactionService.deleteTransaction(id: id)
            withAnimation(.easeOut(duration: 0.2)) {
                transactionsList.removeAll { $0.id == id }
            }
            transactionsTotalCount = max(0, transactionsTotalCount - 1)
            return true
        } catch {
            #if DEBUG
            print("⚠️ deleteTransactionFromList failed: \(error)")
            #endif
            return false
        }
    }

    // MARK: - Goals tab — segments + actions

    /// Active goals (completed_at == nil), sorted by priority asc.
    var activeGoals: [GoalProgress] {
        goalsList
            .filter { $0.completedAt == nil }
            .sorted { ($0.priority ?? Int.max) < ($1.priority ?? Int.max) }
            .compactMap { goalsProgressMap[$0.id] }
    }

    /// Completed goals, newest completion first.
    var completedGoals: [GoalProgress] {
        goalsList
            .filter { $0.completedAt != nil }
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
            .compactMap { goalsProgressMap[$0.id] }
    }

    /// Total saved across all active goals — for the list page header sub-line.
    var totalSavedAcrossActiveGoals: Decimal {
        activeGoals.reduce(Decimal(0)) { $0 + $1.currentAmount }
    }

    /// Load all goals + compute per-goal progress in parallel.
    /// Refreshes `goalsList` + `goalsProgressMap` atomically.
    func loadGoalsList() async {
        guard let userId = session?.user.id else { return }
        goalsLoading = true
        defer { goalsLoading = false }

        let service = GoalService()
        do {
            let goals = try await service.fetchAll(userId: userId)
            let accountsById: [UUID: Account] = Dictionary(
                uniqueKeysWithValues: accounts.map { ($0.id, $0) }
            )

            // Fetch each goal's amounts in parallel.
            var progressMap: [UUID: GoalProgress] = [:]
            await withTaskGroup(of: (UUID, GoalProgress)?.self) { group in
                for goal in goals {
                    group.addTask {
                        let amounts: (contributions: Decimal, payments: Decimal, net: Decimal) =
                            (try? await service.fetchAmounts(goalId: goal.id))
                            ?? (contributions: 0, payments: 0, net: 0)
                        let acc = goal.fundingAccountId.flatMap { accountsById[$0] }
                        let joined = acc.map {
                            JoinedAccountRef(
                                id: $0.id,
                                name: $0.name,
                                accountType: $0.accountType,
                                icon: $0.icon
                            )
                        }
                        let progress = GoalEngine.computeProgress(
                            goal: goal,
                            currentAmount: amounts.net,
                            fundingAccount: joined
                        )
                        return (goal.id, progress)
                    }
                }
                for await pair in group {
                    if let (id, p) = pair { progressMap[id] = p }
                }
            }

            goalsList = goals
            goalsProgressMap = progressMap
        } catch {
            #if DEBUG
            print("⚠️ loadGoalsList failed: \(error)")
            #endif
        }
    }

    /// Contribute to a goal. Inserts a transfer transaction with goal_id,
    /// auto-completes if the target was hit, and fires the savings-streak
    /// + momentum + badge mutation chain (Phase 9 helpers).
    ///
    /// Returns true on success. Errors are swallowed in DEBUG only —
    /// callers display toasts on the boolean.
    @discardableResult
    func contributeToGoal(
        goal: Goal,
        fromAccountId: UUID,
        amount: Decimal,
        note: String?,
        transactionDate: String
    ) async -> Bool {
        guard let userId = session?.user.id else { return false }
        let progress = goalsProgressMap[goal.id]
        let currentAmount: Decimal = progress?.currentAmount ?? 0

        let service = GoalService()
        do {
            _ = try await service.contribute(
                userId: userId,
                goal: goal,
                fromAccountId: fromAccountId,
                amount: amount,
                note: note,
                transactionDate: transactionDate,
                currentAmount: currentAmount
            )

            // Mutation chain (Phase 9 hooks). Fire-and-forget within this
            // method — wait for completion so loadGoalsList sees fresh state,
            // but never throw out of the chain.
            await streakService.updateSavingsStreak(userId: userId)
            await momentumService.award(userId: userId, event: .goalContribution)

            async let contribUnlocks = badgeService.checkAndUnlock(
                userId: userId,
                trigger: .contributionMade
            )
            async let streakUnlocks = badgeService.checkAndUnlock(
                userId: userId,
                trigger: .streakUpdated
            )
            let (cNew, sNew) = await (contribUnlocks, streakUnlocks)
            for badge in cNew + sNew where !unviewedBadgeUnlocks.contains(where: { $0.id == badge.id }) {
                unviewedBadgeUnlocks.append(badge)
            }

            // Refresh: pulls new amounts + auto-completion + score recompute.
            await loadGoalsList()
            await refreshHealthSnapshot()
            return true
        } catch {
            #if DEBUG
            print("⚠️ contributeToGoal failed: \(error)")
            #endif
            return false
        }
    }

    @discardableResult
    func archiveGoal(_ id: UUID) async -> Bool {
        let service = GoalService()
        do {
            try await service.archive(id: id)
            goalsList.removeAll { $0.id == id }
            goalsProgressMap.removeValue(forKey: id)
            return true
        } catch {
            #if DEBUG
            print("⚠️ archiveGoal failed: \(error)")
            #endif
            return false
        }
    }

    @discardableResult
    func deleteGoal(_ id: UUID) async -> Bool {
        let service = GoalService()
        do {
            try await service.delete(id: id)
            goalsList.removeAll { $0.id == id }
            goalsProgressMap.removeValue(forKey: id)
            return true
        } catch {
            #if DEBUG
            print("⚠️ deleteGoal failed: \(error)")
            #endif
            return false
        }
    }

    @discardableResult
    func createGoal(payload: GoalService.CreatePayload) async -> Goal? {
        let service = GoalService()
        do {
            let goal = try await service.create(payload: payload)
            await loadGoalsList()
            return goal
        } catch {
            #if DEBUG
            print("⚠️ createGoal failed: \(error)")
            #endif
            return nil
        }
    }

    @discardableResult
    func updateGoal(id: UUID, payload: GoalService.UpdatePayload) async -> Goal? {
        let service = GoalService()
        do {
            let goal = try await service.update(id: id, payload: payload)
            await loadGoalsList()
            return goal
        } catch {
            #if DEBUG
            print("⚠️ updateGoal failed: \(error)")
            #endif
            return nil
        }
    }

    @discardableResult
    func startNextGoalCycle(
        completedGoal: Goal,
        name: String,
        targetAmount: Decimal,
        deadline: String,
        priority: Int
    ) async -> Goal? {
        guard let userId = session?.user.id else { return nil }
        let service = GoalService()
        do {
            let newGoal = try await service.createNextCycle(
                userId: userId,
                completedGoal: completedGoal,
                name: name,
                targetAmount: targetAmount,
                deadline: deadline,
                priority: priority
            )
            await loadGoalsList()
            return newGoal
        } catch {
            #if DEBUG
            print("⚠️ startNextGoalCycle failed: \(error)")
            #endif
            return nil
        }
    }

    // MARK: - Accounts tab — balance + CRUD + reconcile

    /// Total balance across active accounts. Used by the Accounts tab header.
    var totalActiveBalance: Decimal {
        accounts
            .filter { $0.isActive != false }
            .reduce(Decimal(0)) { $0 + AccountBalanceEngine.balance(for: $1, in: accountsBalances) }
    }

    /// Recompute the per-account balance map. Pulls all transactions for the
    /// current user (minimal field set) and folds via AccountBalanceEngine.
    /// Best-effort: errors leave the map unchanged.
    func recomputeAccountBalances() async {
        guard let userId = session?.user.id else { return }
        do {
            let allTransactions = try await transactionService.fetchAllForBalances(userId: userId)
            self.accountsBalances = AccountBalanceEngine.compute(
                accounts: accounts,
                transactions: allTransactions
            )
        } catch {
            #if DEBUG
            print("⚠️ recomputeAccountBalances failed: \(error)")
            #endif
        }
    }

    /// Reload the accounts list. Reuses the existing fetch helper.
    func reloadAccountsAndBalances() async {
        let fresh = await fetchAccountsOrEmpty()
        self.accounts = fresh
        await recomputeAccountBalances()
    }

    /// Create a new account with single-default enforcement and first-account
    /// auto-default (fix-on-way for web TBD #4).
    /// Returns the created Account on success.
    @discardableResult
    func createAccount(
        name: String,
        type: AccountType,
        openingBalance: Decimal,
        isDefault userIsDefault: Bool
    ) async -> Account? {
        guard let userId = session?.user.id else { return nil }
        let service = AccountService()

        let isFirstAccount = accounts.filter { $0.isActive != false }.isEmpty
        let effectiveDefault = isFirstAccount || userIsDefault

        do {
            // Step 1: clear other defaults if this one will be default
            if effectiveDefault {
                try await service.clearAllDefaults(userId: userId)
            }

            // Step 2: insert
            let cfg = AccountTypeConfigs.config(for: type)
            let payload = AccountService.AccountInsert(
                user_id: userId,
                name: name,
                account_type: type.rawValue,
                icon: cfg.emoji,                  // dead-write
                color: cfg.hexString,             // dead-write
                opening_balance: openingBalance,
                is_default: effectiveDefault,
                is_active: true,
                sort_order: accounts.count + 1
            )
            let created = try await service.create(payload: payload)

            // Step 3: refresh local state — get updated default flags across rows
            await reloadAccountsAndBalances()
            return created
        } catch {
            #if DEBUG
            print("⚠️ createAccount failed: \(error)")
            #endif
            return nil
        }
    }

    /// Update an existing account.
    @discardableResult
    func updateAccount(
        id: UUID,
        name: String,
        type: AccountType,
        openingBalance: Decimal,
        isDefault: Bool,
        isActive: Bool
    ) async -> Account? {
        guard let userId = session?.user.id else { return nil }
        let service = AccountService()

        let existing = accounts.first(where: { $0.id == id })

        do {
            // Single-default enforcement: only clear others if this update
            // is promoting the row to default (was false, now true).
            if isDefault, existing?.isDefault != true {
                try await service.clearAllDefaults(userId: userId)
            }

            let cfg = AccountTypeConfigs.config(for: type)
            let payload = AccountService.AccountUpdate(
                name: name,
                account_type: type.rawValue,
                icon: cfg.emoji,
                color: cfg.hexString,
                opening_balance: openingBalance,
                is_default: isDefault,
                is_active: isActive
            )
            let updated = try await service.update(id: id, payload: payload)
            await reloadAccountsAndBalances()
            return updated
        } catch {
            #if DEBUG
            print("⚠️ updateAccount failed: \(error)")
            #endif
            return nil
        }
    }

    /// Inline reconcile (from the Edit modal expander). Inserts an adjustment
    /// transaction for the diff and refreshes balances.
    ///
    /// TODO (Phase 9.5b): port `awardMomentum(.accountReconciled)` and
    /// `checkAndUnlockBadges(.accountReconciled)` here AND in the standalone
    /// reconcile sheet. Both reconcile paths should fire the same chain.
    @discardableResult
    func reconcileAccountInline(
        accountId: UUID,
        sikaBalance: Decimal,
        actualBalance: Decimal
    ) async -> Bool {
        guard let userId = session?.user.id else { return false }
        let service = AccountService()
        do {
            try await service.insertReconcileAdjustment(
                userId: userId,
                accountId: accountId,
                sikaBalance: sikaBalance,
                actualBalance: actualBalance
            )
            await recomputeAccountBalances()
            return true
        } catch {
            #if DEBUG
            print("⚠️ reconcileAccountInline failed: \(error)")
            #endif
            return false
        }
    }

    /// Pre-delete count. Caller uses this to decide between confirm-only
    /// flow (count == 0) and reassign overlay flow (count > 0).
    func countTransactionsForAccount(_ accountId: UUID) async -> Int {
        let service = AccountService()
        do {
            return try await service.countTransactionsReferencingAccountId(accountId)
        } catch {
            return 0
        }
    }

    /// Delete an account. If `reassignTo` is non-nil, transactions referencing
    /// the source account_id are bulk-updated first. FK errors on
    /// goals.funding_account_id, recurring_transactions.account_id, or
    /// transactions.to_account_id surface as a thrown error → false return.
    @discardableResult
    func deleteAccountWithReassign(
        _ id: UUID,
        reassignTo targetId: UUID?
    ) async -> Bool {
        let service = AccountService()
        do {
            if let target = targetId {
                try await service.reassignTransactions(from: id, to: target)
            }
            try await service.delete(id: id)
            self.accounts.removeAll { $0.id == id }
            self.accountsBalances.removeValue(forKey: id)
            await recomputeAccountBalances()
            return true
        } catch {
            #if DEBUG
            print("⚠️ deleteAccountWithReassign failed: \(error)")
            #endif
            return false
        }
    }
}
