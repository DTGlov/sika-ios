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
                            onSwitchToTransactions: { selectedTab = .transactions }
                        )
                    }
                case .transactions:
                    TransactionsTabPlaceholder()
                case .accounts:
                    AccountsTabPlaceholder()
                case .goals:
                    GoalsTabPlaceholder()
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
