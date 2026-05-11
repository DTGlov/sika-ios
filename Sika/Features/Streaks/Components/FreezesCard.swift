import SwiftUI

/// Streak freezes card. Header (snowflake + title) + counter line +
/// 2 visual slots (filled = banked, empty = unfilled) + helper text.
///
/// `MAX_FREEZES = 2` matches web — the cap is hardcoded both ends.
struct FreezesCard: View {
    let freezesBanked: Int
    let freezesEarnedTotal: Int

    private let blueAccent = Color(hex: 0x60A5FA)
    private static let maxFreezes: Int = 2

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            counterLine
            slotsRow
            helperText
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SikaTheme.Color.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(SikaTheme.Color.mutedForeground.opacity(0.15), lineWidth: 1)
        )
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "snowflake")
                .font(.system(size: 16))
                .foregroundStyle(blueAccent)
            Text("Streak Freezes")
                .font(SikaTheme.Typography.sans(15, weight: .semibold))
                .foregroundStyle(SikaTheme.Color.foreground)
            Spacer()
        }
    }

    private var counterLine: some View {
        HStack(spacing: 4) {
            Text("\(freezesBanked)")
                .font(SikaTheme.Typography.sans(13, weight: .semibold))
                .foregroundStyle(SikaTheme.Color.foreground)
                .monospacedDigit()
            Text("banked ·")
                .font(SikaTheme.Typography.sans(13))
                .foregroundStyle(SikaTheme.Color.mutedForeground)
            Text("\(freezesEarnedTotal)")
                .font(SikaTheme.Typography.sans(13, weight: .semibold))
                .foregroundStyle(SikaTheme.Color.foreground)
                .monospacedDigit()
            Text("earned total")
                .font(SikaTheme.Typography.sans(13))
                .foregroundStyle(SikaTheme.Color.mutedForeground)
            Spacer()
        }
    }

    private var slotsRow: some View {
        HStack(spacing: 10) {
            ForEach(0..<Self.maxFreezes, id: \.self) { index in
                freezeSlot(filled: index < freezesBanked)
            }
            Spacer()
        }
    }

    private func freezeSlot(filled: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(filled ? blueAccent.opacity(0.15) : SikaTheme.Color.muted)
                .frame(width: 40, height: 40)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            filled
                                ? blueAccent.opacity(0.30)
                                : SikaTheme.Color.mutedForeground.opacity(0.20),
                            lineWidth: 1
                        )
                )
            if filled {
                Image(systemName: "snowflake")
                    .font(.system(size: 18))
                    .foregroundStyle(blueAccent)
            }
        }
    }

    private var helperText: some View {
        Text("Freezes protect your streak when life gets in the way. Earn 1 every 10 days of logging. Max 2 banked.")
            .font(SikaTheme.Typography.sans(12))
            .foregroundStyle(SikaTheme.Color.mutedForeground)
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
    }
}
