import SwiftUI

struct AuthenticatedRootView: View {
    let profile: Profile

    @Environment(AppState.self) private var appState
    @State private var selectedTab: MainTab = .home
    @State private var isAddTransactionPresented: Bool = false

    // T3 — reconcile entry from the wizard's ReconcileLink. The wizard
    // dismisses, then the standalone ReconcileAccountSheet opens with
    // the preselected account (may be nil if the user hadn't picked one).
    @State private var reconcileTarget: Account? = nil
    @State private var isReconcileFromWizardPresented: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch selectedTab {
                case .home:
                    NavigationStack {
                        AuthenticatedHomeView(
                            profile: profile,
                            onSwitchToTransactions: { selectedTab = .transactions },
                            onSwitchToTab: { selectedTab = $0 }
                        )
                    }
                case .transactions:
                    TransactionsView()
                case .accounts:
                    NavigationStack {
                        AccountsView()
                    }
                case .goals:
                    NavigationStack {
                        GoalsView()
                    }
                case .recurring:
                    NavigationStack {
                        RecurringView()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(SikaTheme.Color.background)

            MainTabBar(selectedTab: $selectedTab)
        }
        .background(SikaTheme.Color.background)
        .ignoresSafeArea(.keyboard)
        .overlay(alignment: .bottom) {
            // Global momentum-float bubbles. Any surface that calls
            // appState.enqueueMomentumFloat(points:) renders here. Sits
            // BEHIND the FAB overlay so the bubbles don't intercept taps.
            MomentumFloatContainer()
        }
        .overlay(alignment: .top) {
            // Global milestone toast. Fires 500ms after the type-aware
            // "Logged" toast and lasts 3s.
            MilestoneToastView()
        }
        .overlay(alignment: .top) {
            // T3 — global amber warning toast for IBS "Log anyway" outcome.
            // Separate overlay so it can coexist with the milestone toast
            // (they don't fire from the same flow, but layering them lets
            // each animate cleanly).
            WarningToastView()
        }
        .overlay(alignment: .bottomTrailing) {
            FloatingActionButton(
                action: { isAddTransactionPresented = true }
            )
            .padding(.trailing, SikaTheme.Spacing.lg)
            .padding(.bottom, 80)
        }
        .sheet(isPresented: $isAddTransactionPresented) {
            AddTransactionWizardView(
                accounts: appState.accounts,
                categories: appState.categories,
                onReconcileTap: { picked in
                    // Dismiss wizard, then present reconcile after the
                    // dismiss animation settles. Without the delay the
                    // sheet-swap conflicts and the second sheet stays
                    // suppressed.
                    reconcileTarget = picked ?? appState.accounts.first(where: { $0.isActive != false })
                    isAddTransactionPresented = false
                    Task {
                        try? await Task.sleep(for: .milliseconds(350))
                        if reconcileTarget != nil {
                            isReconcileFromWizardPresented = true
                        }
                    }
                }
            )
        }
        .sheet(isPresented: $isReconcileFromWizardPresented) {
            if let acc = reconcileTarget {
                ReconcileAccountSheet(
                    account: acc,
                    currentBalance: AccountBalanceEngine.balance(for: acc, in: appState.accountsBalances),
                    currencyCode: appState.currencyCode,
                    onCompleted: { }
                )
            }
        }
    }
}
