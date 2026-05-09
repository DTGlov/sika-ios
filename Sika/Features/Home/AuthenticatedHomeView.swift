import SwiftUI

/// Home dashboard. Phase 4 adds the dismissible hint system: 2 HintCards
/// (`dashboard_card_intro` below CycleCard, `dashboard_buckets_intro` above
/// BucketStrip) plus SundayRecapCard between SpendCardPair and GoalsWidget.
/// Pull-to-refresh re-fetches all Home data sources in parallel.
///
/// Deferred to later phases:
/// - Phase 2.1: Goal progress derivation (current saved per goal)
/// - Phase 5: Daily / Insight / Monthly banners
/// - Phase 6: 6 more heritage themes
/// - Phase 7+: income nudges, recurring cards, Should I Buy, gamification
struct AuthenticatedHomeView: View {
    let profile: Profile
    /// Closure used by ShouldIBuyButton's "I bought it" flow to switch the
    /// main tab to Transactions. Owned by `AuthenticatedRootView`.
    let onSwitchToTransactions: () -> Void

    @Environment(AppState.self) private var appState
    @State private var isSettingsPresented = false
    /// Bound to NavigationStack push for MonthlyRecapDetailView. The banner's
    /// onTap sets this; the destination closure renders the detail page.
    /// Keeping the recap as State (not just an id) so the detail keeps its
    /// data even after AppState.monthlyRecap clears via markViewed.
    @State private var navigatedRecap: MonthlyRecap? = nil
    /// Bound to NavigationStack push for DailyDigestDetailView. Same pattern
    /// as `navigatedRecap` — captures the digest at tap time so the detail
    /// view keeps it after AppState.digestRead flips.
    @State private var navigatedDigest: DailyDigest? = nil
    /// Bound to NavigationStack push for CycleDetailView. Set when the user
    /// taps the heritage CycleCard. Captures the currently-displayed cycle
    /// (which may be the current cycle or a past one navigated via chevron).
    @State private var navigatedCycle: Cycle? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: SikaTheme.Spacing.lg) {
                HomeTopBar(
                    firstName: profile.firstName,
                    onSettingsTap: {
                        isSettingsPresented = true
                    }
                )

                CycleNavRow(
                    cycle: appState.currentCycle,
                    isOnCurrentCycle: appState.isOnCurrentCycle,
                    onPrevious: { appState.goToPreviousCycle() },
                    onNext: { appState.goToNextCycle() }
                )

                if appState.shouldShowDailyDigestBanner, let digest = appState.todayDigest {
                    DailyDigestBanner(
                        digest: digest,
                        onTap: { navigatedDigest = digest }
                    )
                    .padding(.horizontal, SikaTheme.Spacing.lg)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                if let insightRow = appState.dailyInsight {
                    DailyInsightBanner(
                        insight: insightRow.insightData,
                        onDismiss: {
                            Task { await appState.dismissDailyInsight() }
                        }
                    )
                    .padding(.horizontal, SikaTheme.Spacing.lg)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                if let recap = appState.monthlyRecap {
                    MonthlyRecapBanner(
                        onTap: { navigatedRecap = recap },
                        onDismiss: {
                            Task { await appState.dismissMonthlyRecap() }
                        }
                    )
                    .padding(.horizontal, SikaTheme.Spacing.lg)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                CycleCard(
                    cycleNet: SpendCalculator.cycleNet(
                        transactions: appState.transactions,
                        cycle: appState.currentCycle
                    ),
                    userName: profile.fullName,
                    theme: cardTheme,
                    currencyCode: appState.currencyCode,
                    onTap: { navigatedCycle = appState.currentCycle }
                )
                .padding(.horizontal, SikaTheme.Spacing.lg)

                HintCard(
                    hintId: .dashboardCardIntro,
                    title: "This is your month card",
                    message: "It shows money that came in minus money that went out this month. Resets at the start of each month. Customize the style in Settings."
                )
                .padding(.horizontal, SikaTheme.Spacing.lg)

                CycleStatLine(
                    received: SpendCalculator.cycleReceived(
                        transactions: appState.transactions,
                        cycle: appState.currentCycle
                    ),
                    spent: SpendCalculator.cycleSpent(
                        transactions: appState.transactions,
                        cycle: appState.currentCycle
                    ),
                    expectedMonthly: appState.monthlyIncomeAmount,
                    currencyCode: appState.currencyCode
                )

                Divider()
                    .padding(.horizontal, SikaTheme.Spacing.lg)
                    .padding(.vertical, SikaTheme.Spacing.sm)

                SpendCardPair(
                    todaySpent: SpendCalculator.todaysSpent(transactions: appState.transactions),
                    thisMonthSpent: SpendCalculator.currentMonthSpent(transactions: appState.transactions),
                    deltaPercent: SpendCalculator.monthOverMonthDeltaPercent(
                        current: SpendCalculator.currentMonthSpent(transactions: appState.transactions),
                        previous: SpendCalculator.previousMonthSpent(transactions: appState.transactions)
                    ),
                    currencyCode: appState.currencyCode
                )

                ShouldIBuyButton(onSwitchToTransactions: onSwitchToTransactions)
                    .padding(.horizontal, SikaTheme.Spacing.lg)

                SundayRecapCard()
                    .padding(.horizontal, SikaTheme.Spacing.lg)

                HealthRow(
                    snapshot: appState.healthSnapshot,
                    hasLoggedToday: appState.hasLoggedToday
                )
                .padding(.horizontal, SikaTheme.Spacing.lg)

                if !appState.incomeNudges.isEmpty || !appState.visiblePendingRecurring.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(appState.incomeNudges) { nudge in
                            IncomeNudgeCardView(
                                nudge: nudge,
                                currencyCode: appState.currencyCode,
                                onLog: { n in Task { await appState.logIncomeNudge(n) } },
                                onSnooze: { n in Task { await appState.snoozeIncomeNudge(n) } },
                                onDismiss: { n in Task { await appState.dismissIncomeNudge(n) } }
                            )
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                        ForEach(appState.visiblePendingRecurring) { pending in
                            PendingRecurringCardView(
                                pending: pending,
                                currencyCode: appState.currencyCode,
                                onConfirm: { p in Task { await appState.confirmPendingRecurring(p) } },
                                onSkip: { p in Task { await appState.skipPendingRecurring(p) } }
                            )
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .padding(.horizontal, SikaTheme.Spacing.lg)
                }

                GoalsWidget(
                    goals: appState.topGoals,
                    transactions: appState.transactions,
                    currencyCode: appState.currencyCode,
                    onSeeAllTap: {
                        // Phase 2: no-op — /goals detail route ships later.
                    }
                )

                HintCard(
                    hintId: .dashboardBucketsIntro,
                    title: "How buckets work",
                    message: "Your income is split 50/30/20 by default: Needs (must-haves like rent, food, transport), Wants (eating out, entertainment, gym), Savings (savings, investments, emergency fund). Customize the split in Settings.",
                    cta: "Got it"
                )
                .padding(.horizontal, SikaTheme.Spacing.lg)

                BucketStrip(
                    rows: BucketSpendCalculator.compute(
                        transactions: appState.transactions,
                        categories: appState.categories,
                        budgetBuckets: appState.budgetBuckets,
                        accounts: appState.accounts,
                        cycle: appState.currentCycle,
                        monthlyIncome: appState.monthlyIncomeAmount,
                        needsPercent: profile.needsPercentValue,
                        wantsPercent: profile.wantsPercentValue,
                        savingsPercent: profile.savingsPercentValue
                    ),
                    needsPercent: profile.needsPercentValue,
                    wantsPercent: profile.wantsPercentValue,
                    savingsPercent: profile.savingsPercentValue,
                    currencyCode: appState.currencyCode,
                    onTap: {
                        // Phase 2: no-op — /buckets detail route ships later.
                    }
                )

                WeeklyChart(
                    transactions: appState.transactionsInDisplayedCycle,
                    cycle: appState.currentCycle,
                    currencyCode: appState.currencyCode
                )

                RecentTransactionsWidget(
                    transactions: appState.transactionsInDisplayedCycle,
                    categories: appState.categories,
                    currencyCode: appState.currencyCode,
                    onSeeAllTap: {
                        // Phase 2: no-op — /transactions detail route ships later.
                    }
                )

                Spacer().frame(height: SikaTheme.Spacing.xl2)
            }
            .padding(.top, SikaTheme.Spacing.md)
        }
        .background(SikaTheme.Color.background)
        .refreshable {
            await appState.refreshHomeData()
        }
        .sheet(isPresented: $isSettingsPresented) {
            SettingsView()
        }
        .navigationDestination(item: $navigatedRecap) { recap in
            MonthlyRecapDetailView(
                recap: recap,
                onAppear: {
                    Task { await appState.markMonthlyRecapViewed(recapId: recap.id) }
                },
                onShare: {
                    Task { await appState.markMonthlyRecapShared(recapId: recap.id) }
                }
            )
        }
        .navigationDestination(item: $navigatedDigest) { digest in
            DailyDigestDetailView(
                digest: digest,
                isInitiallyRead: appState.digestRead,
                onMarkRead: { await appState.markDigestRead() }
            )
        }
        .navigationDestination(item: $navigatedCycle) { cycle in
            CycleDetailView(cycle: cycle)
        }
        .fullScreenCover(item: nextBadgeCelebration) { badge in
            BadgeCelebrationSheet(
                userBadge: badge,
                onDismiss: { await appState.dismissBadgeCelebration(badge) }
            )
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    /// Binding to the head of the badge-celebration queue. Reading the head
    /// drives the .fullScreenCover; the setter is a no-op (the cover never
    /// dismisses itself externally — only via dismissBadgeCelebration).
    private var nextBadgeCelebration: Binding<UserBadge?> {
        Binding(
            get: { appState.unviewedBadgeUnlocks.first },
            set: { _ in }
        )
    }

    /// Resolve the heritage theme for the cycle card from profile.cardTheme,
    /// defaulting to .sankofa if unknown or unparseable.
    private var cardTheme: HeritageCardTheme {
        HeritageCardTheme(rawValue: profile.cardTheme) ?? .sankofa
    }
}
