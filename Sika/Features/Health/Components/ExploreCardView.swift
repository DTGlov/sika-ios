import SwiftUI

/// Tile in the /health detail Explore section's 2×2 grid.
/// Chrome per audit Section: 16pt corner radius, 1pt muted stroke,
/// 16/12 padding, icon (16pt SF symbol in card-specific color) +
/// label (muted, NOT tinted) on the left, chevron on the right.
struct ExploreCardView: View {
    let iconName: String
    let iconColor: Color
    let label: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                HStack(spacing: 10) {
                    Image(systemName: iconName)
                        .font(.system(size: 16))
                        .foregroundStyle(iconColor)
                        .frame(width: 16, height: 16)
                    Text(label)
                        .font(SikaTheme.Typography.sans(14))
                        .foregroundStyle(SikaTheme.Color.mutedForeground)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(SikaTheme.Color.mutedForeground.opacity(0.6))
                    .frame(width: 16, height: 16)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(SikaTheme.Color.card)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(SikaTheme.Color.mutedForeground.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
