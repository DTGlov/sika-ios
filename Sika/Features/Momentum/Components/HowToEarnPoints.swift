import SwiftUI

/// "How to Earn Points" table: 7 rows from `MomentumAmounts.entries`
/// in INSERTION ORDER (NOT sorted by points) — matches web's
/// MOMENTUM_AMOUNTS display order. Includes unwired events
/// (transaction_logged_via_nudge, bucket_within_limit_full_month)
/// for cross-platform parity.
struct HowToEarnPoints: View {
    private let goldAccent = Color(hex: 0xD4A017)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How to Earn Points")
                .font(SikaTheme.Typography.sans(15, weight: .semibold))
                .foregroundStyle(SikaTheme.Color.foreground)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                ForEach(Array(MomentumAmounts.entries.enumerated()), id: \.offset) { index, entry in
                    earnRow(label: entry.label, points: entry.type.points)
                    if index < MomentumAmounts.entries.count - 1 {
                        Divider().background(SikaTheme.Color.mutedForeground.opacity(0.1))
                    }
                }
            }
            .padding(.vertical, 4)
            .background(SikaTheme.Color.card)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private func earnRow(label: String, points: Int) -> some View {
        HStack {
            Text(label)
                .font(SikaTheme.Typography.sans(13))
                .foregroundStyle(SikaTheme.Color.mutedForeground)
            Spacer()
            Text("+\(points)")
                .font(SikaTheme.Typography.sans(13, weight: .semibold))
                .foregroundStyle(goldAccent)
                .monospacedDigit()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
