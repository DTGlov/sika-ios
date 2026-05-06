import SwiftUI

struct MainTabBar: View {
    @Binding var selectedTab: MainTab

    private let tabs: [MainTab] = [.home, .transactions, .accounts, .goals, .recurring]

    var body: some View {
        ZStack(alignment: .top) {
            Rectangle()
                .fill(SikaTheme.Color.background)
                .frame(height: 64)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(SikaTheme.Color.border)
                        .frame(height: 0.5)
                }

            HStack(spacing: 0) {
                ForEach(tabs, id: \.id) { tab in
                    TabBarButton(
                        tab: tab,
                        isActive: selectedTab == tab,
                        action: { selectedTab = tab }
                    )
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 64)
        }
        .frame(height: 64)
    }
}

private struct TabBarButton: View {
    let tab: MainTab
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: isActive ? tab.activeIconName : tab.iconName)
                    .font(.system(size: 22, weight: isActive ? .semibold : .regular))
                    .foregroundStyle(isActive
                        ? SikaTheme.Color.sikaAccent
                        : SikaTheme.Color.mutedForeground)
                Text(tab.label)
                    .font(SikaTheme.Typography.sans(11, weight: isActive ? .semibold : .regular))
                    .foregroundStyle(isActive
                        ? SikaTheme.Color.sikaAccent
                        : SikaTheme.Color.mutedForeground)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
    }
}
