import SwiftUI

struct AuthenticatedRootView: View {
    let profile: Profile

    @Environment(AppState.self) private var appState
    @State private var selectedTab: MainTab = .home
    @State private var isAddTransactionPresented: Bool = false

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
                categories: appState.categories
            )
        }
    }
}
