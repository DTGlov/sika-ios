import SwiftUI

/// Shared shell used by the three /health Explore section placeholders.
/// Phase 9.5b will replace each concrete wrapper (`StreakDetailPlaceholderView`,
/// `MomentumDetailPlaceholderView`, `BadgesGridPlaceholderView`) with the
/// real destination; the wrappers exist so the navigation glue in
/// `HealthDetailView` doesn't have to change when the real surfaces ship.
struct HealthPlaceholderShell: View {
    let iconName: String
    let iconColor: Color
    let title: String
    let comingSoonCopy: String

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: iconName)
                .font(.system(size: 48))
                .foregroundStyle(iconColor)
            Text(title)
                .font(SikaTheme.Typography.sans(20, weight: .bold))
                .foregroundStyle(SikaTheme.Color.foreground)
            Text(comingSoonCopy)
                .font(SikaTheme.Typography.sans(13))
                .foregroundStyle(SikaTheme.Color.mutedForeground)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SikaTheme.Color.background)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
