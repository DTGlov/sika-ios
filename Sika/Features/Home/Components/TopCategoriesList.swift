import SwiftUI

/// "Top spending categories" list. CAPPED AT 5 (already capped by
/// CycleDetailService.aggregate). Each row: name + amount + horizontal
/// progress bar at percentage of total.
///
/// Bar fill is HARDCODED rose `#F43F5E` at 60% opacity — NOT category color,
/// NOT bucket color, NOT theme color. Uniform "spent" treatment.
struct TopCategoriesList: View {
    let rows: [CycleBreakdownRow]
    let totalSpent: Decimal
    let currencyCode: String

    private let barColor = Color(hex: 0xF43F5E).opacity(0.6)

    private func percentage(for amount: Decimal) -> Double {
        guard totalSpent > 0 else { return 0 }
        return Double(truncating: ((amount / totalSpent) * 100) as NSNumber)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TOP SPENDING CATEGORIES")
                .font(.system(size: 11, weight: .medium))
                .tracking(1.2)
                .foregroundStyle(SikaTheme.Color.mutedForeground)

            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    VStack(spacing: 6) {
                        HStack {
                            Text(row.name)
                                .font(SikaTheme.Typography.sans(14))
                                .foregroundStyle(SikaTheme.Color.foreground)
                                .lineLimit(1)
                                .truncationMode(.tail)

                            Spacer(minLength: 12)

                            Text(CurrencyFormatter.format(row.amount, code: currencyCode))
                                .font(SikaTheme.Typography.sans(14, weight: .medium))
                                .monospacedDigit()
                                .foregroundStyle(SikaTheme.Color.foreground)
                        }

                        SpendingBar(
                            percentage: percentage(for: row.amount),
                            fillColor: barColor
                        )
                    }
                    .padding(.horizontal, SikaTheme.Spacing.md)
                    .padding(.vertical, 12)

                    if index < rows.count - 1 {
                        Divider()
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(SikaTheme.Color.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(SikaTheme.Color.border, lineWidth: 1)
                    )
            )
        }
    }
}

/// Horizontal progress bar. 4pt tall. Track is muted, fill is rose 60%.
private struct SpendingBar: View {
    let percentage: Double  // 0..100
    let fillColor: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(SikaTheme.Color.muted)

                Capsule()
                    .fill(fillColor)
                    .frame(width: max(0, geo.size.width * percentage / 100))
            }
        }
        .frame(height: 4)
    }
}
