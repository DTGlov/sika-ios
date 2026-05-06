import SwiftUI

struct RecurringTabPlaceholder: View {
    var body: some View {
        VStack(spacing: SikaTheme.Spacing.md) {
            Image(systemName: MainTab.recurring.iconName)
                .font(.system(size: 48))
                .foregroundStyle(SikaTheme.Color.mutedForeground)
            Text(MainTab.recurring.label)
                .font(SikaTheme.Typography.sans(20, weight: .bold))
                .foregroundStyle(SikaTheme.Color.foreground)
            Text("Coming soon")
                .font(SikaTheme.Typography.sans(14))
                .foregroundStyle(SikaTheme.Color.mutedForeground)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SikaTheme.Color.background)
    }
}
