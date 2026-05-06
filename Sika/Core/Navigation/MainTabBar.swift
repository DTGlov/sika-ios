import SwiftUI

struct MainTabBar: View {
    @Binding var selectedTab: MainTab
    let onTapFAB: () -> Void

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
                ForEach(Array(tabs.enumerated()), id: \.element.id) { index, tab in
                    TabBarButton(
                        tab: tab,
                        isActive: selectedTab == tab,
                        action: { selectedTab = tab }
                    )
                    .frame(maxWidth: .infinity)

                    // After the 2nd tab (Transactions), reserve space for the FAB.
                    if index == 1 {
                        Spacer().frame(width: 76)
                    }
                }
            }
            .frame(height: 64)
        }
        .frame(height: 64)
        .overlay(alignment: .top) {
            FabButton(action: onTapFAB)
                .offset(y: -20)
                .frame(maxWidth: .infinity, alignment: .center)
        }
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

private struct FabButton: View {
    let action: () -> Void
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(SikaTheme.Color.sikaAccent.opacity(0.18))
                    .frame(width: 76, height: 76)
                    .blur(radius: 6)

                Circle()
                    .fill(SikaTheme.Color.sikaAccent)
                    .frame(width: 56, height: 56)
                    .shadow(color: SikaTheme.Color.sikaAccent.opacity(0.4), radius: 12, y: 4)

                Image(systemName: "plus")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(SikaTheme.Color.primaryForeground)
            }
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isPressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .accessibilityLabel("Add transaction")
    }
}
