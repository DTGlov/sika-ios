import SwiftUI

/// "Your month in money is ready" banner.
/// Surfaces when the user has a recent monthly_recaps row with viewed_at AND
/// dismissed_at both null and generated_at within the last 30 days.
///
/// Visual spec mirrors web's MonthlyRecapBanner:
/// - card background, 1pt amber border at 20% opacity, faint amber glow
/// - Layout: 🔥 + title + subtitle | chevron + X
/// - Tapping body navigates; tapping X dismisses (no nav).
struct MonthlyRecapBanner: View {
    let onTap: () -> Void
    let onDismiss: () -> Void

    private let amberColor = Color(hex: 0xFBBF24)

    var body: some View {
        HStack(alignment: .center, spacing: SikaTheme.Spacing.md) {
            Button(action: onTap) {
                HStack(alignment: .center, spacing: SikaTheme.Spacing.md) {
                    Text("🔥")
                        .font(.system(size: 20))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Your month in money is ready")
                            .font(SikaTheme.Typography.sans(14, weight: .semibold))
                            .foregroundStyle(SikaTheme.Color.foreground)
                            .multilineTextAlignment(.leading)

                        Text("5–7 takeaways from your last budget cycle →")
                            .font(SikaTheme.Typography.sans(12))
                            .foregroundStyle(SikaTheme.Color.mutedForeground)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(SikaTheme.Color.mutedForeground)
                }
            }
            .buttonStyle(.plain)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(SikaTheme.Color.mutedForeground.opacity(0.7))
                    .padding(.leading, 4)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss monthly recap")
        }
        .padding(.horizontal, SikaTheme.Spacing.md)
        .padding(.vertical, SikaTheme.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(SikaTheme.Color.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(amberColor.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: amberColor.opacity(0.06), radius: 20, x: 0, y: 0)
        )
    }
}
