import SwiftUI

struct AuthenticatedRootView: View {
    let profile: Profile

    @State private var selectedTab: MainTab = .home
    @State private var isAddTransactionPresented: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch selectedTab {
                case .home:
                    AuthenticatedHomeView(profile: profile)
                case .transactions:
                    TransactionsTabPlaceholder()
                case .accounts:
                    AccountsTabPlaceholder()
                case .goals:
                    GoalsTabPlaceholder()
                case .recurring:
                    RecurringTabPlaceholder()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(SikaTheme.Color.background)

            MainTabBar(
                selectedTab: $selectedTab,
                onTapFAB: { isAddTransactionPresented = true }
            )
        }
        .background(SikaTheme.Color.background)
        .ignoresSafeArea(.keyboard)
        .sheet(isPresented: $isAddTransactionPresented) {
            AddTransactionSheet()
        }
    }
}
