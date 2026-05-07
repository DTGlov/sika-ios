import SwiftUI

/// 2-column grid: Today + This Month (with prev-month delta).
struct SpendCardPair: View {
    let todaySpent: Decimal
    let thisMonthSpent: Decimal
    let deltaPercent: Decimal?
    var currencyCode: String = "GHS"

    var body: some View {
        HStack(spacing: SikaTheme.Spacing.md) {
            SpendCard(
                title: "Today",
                amount: todaySpent,
                currencyCode: currencyCode
            )
            SpendCard(
                title: "This Month",
                amount: thisMonthSpent,
                currencyCode: currencyCode,
                deltaPercent: deltaPercent,
                deltaLabel: "vs prev month"
            )
        }
        .padding(.horizontal, SikaTheme.Spacing.lg)
    }
}
