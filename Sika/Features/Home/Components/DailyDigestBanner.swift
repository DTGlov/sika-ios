import SwiftUI

/// "Today's Sika Daily" banner. Surfaces when:
/// - Today's digest row exists in sika_daily_digests
/// - User hasn't marked it read in user_daily_reads
///
/// Visual spec mirrors web's SikaDailyBanner
/// (src/components/dashboard/sika-daily-banner.tsx):
/// - card background, 1pt gold border at 20% opacity (#D4A017)
/// - Faint Sika-green glow shadow (rgba(0, 217, 163, 0.08))
/// - Layout: 📰 + 2-line text + chevron-right
/// - Whole card is the tap target — no X button on the banner itself.
struct DailyDigestBanner: View {
    let digest: DailyDigest
    let onTap: () -> Void

    private var subtitleText: String {
        let count = digest.stories.count
        let countLabel = count == 1 ? "story" : "stories"
        let freshness = digest.isFallback ? "Catch up" : "Fresh picks"
        return "\(count) \(countLabel) · \(freshness)"
    }

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: SikaTheme.Spacing.md) {
                Text("📰")
                    .font(.system(size: 20))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Today's Sika Daily")
                        .font(SikaTheme.Typography.sans(14, weight: .semibold))
                        .foregroundStyle(SikaTheme.Color.foreground)
                        .multilineTextAlignment(.leading)

                    Text(subtitleText)
                        .font(SikaTheme.Typography.sans(12))
                        .foregroundStyle(SikaTheme.Color.mutedForeground)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(SikaTheme.Color.mutedForeground)
            }
            .padding(.horizontal, SikaTheme.Spacing.md)
            .padding(.vertical, SikaTheme.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(SikaTheme.Color.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                SikaTheme.Color.sikaAccent.opacity(0.2),
                                lineWidth: 1
                            )
                    )
                    .shadow(
                        color: SikaTheme.Color.sikaSuccess.opacity(0.08),
                        radius: 20, x: 0, y: 0
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
