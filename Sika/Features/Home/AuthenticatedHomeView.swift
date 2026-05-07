import SwiftUI

/// Phase 1 Home dashboard: top bar + cycle navigation + heritage CycleCard +
/// stat line + SpendCard pair. Pull-to-refresh re-fetches all Home data.
///
/// Deferred to later phases:
/// - Phase 2: Goals widget, Buckets strip, Recent transactions list
/// - Phase 3: Weekly chart (Apple Charts framework)
/// - Phase 4: Tutorial cards / dismissible hints
/// - Phase 5: Daily / Insight / Monthly banners
/// - Phase 6: 6 more heritage themes
struct AuthenticatedHomeView: View {
    let profile: Profile

    @Environment(AppState.self) private var appState
    @State private var isSettingsPresented = false

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

                CycleCard(
                    cycleNet: SpendCalculator.cycleNet(
                        transactions: appState.transactions,
                        cycle: appState.currentCycle
                    ),
                    userName: profile.fullName,
                    theme: cardTheme,
                    currencyCode: appState.currencyCode
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

                Spacer().frame(height: SikaTheme.Spacing.xl2)
            }
            .padding(.top, SikaTheme.Spacing.md)
        }
        .background(SikaTheme.Color.background)
        .refreshable {
            await appState.refreshHomeData()
        }
        .onAppear {
            #if DEBUG
            appState.debugPrintHomeData()
            #endif
        }
        .sheet(isPresented: $isSettingsPresented) {
            SettingsView()
        }
    }

    /// Resolve the heritage theme for the cycle card from profile.cardTheme,
    /// defaulting to .sankofa if unknown or unparseable.
    private var cardTheme: HeritageCardTheme {
        HeritageCardTheme(rawValue: profile.cardTheme) ?? .sankofa
    }
}
