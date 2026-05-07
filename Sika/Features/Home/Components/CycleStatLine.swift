import SwiftUI

/// "Received GHS X · Spent GHS Y · Expected GHS Z/mo" caption beneath cycle card.
struct CycleStatLine: View {
    let received: Decimal
    let spent: Decimal
    let expectedMonthly: Decimal
    var currencyCode: String = "GHS"

    var body: some View {
        HStack(spacing: SikaTheme.Spacing.xs) {
            statItem(label: "Received", amount: received, suffix: nil)
            separator
            statItem(label: "Spent", amount: spent, suffix: nil)
            separator
            statItem(label: "Expected", amount: expectedMonthly, suffix: "/mo")
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, SikaTheme.Spacing.lg)
    }

    @ViewBuilder
    private func statItem(label: String, amount: Decimal, suffix: String?) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(SikaTheme.Typography.sans(12))
                .foregroundStyle(SikaTheme.Color.mutedForeground)
            Text(CurrencyFormatter.compact(amount, code: currencyCode))
                .font(SikaTheme.Typography.sans(12, weight: .semibold))
                .foregroundStyle(SikaTheme.Color.foreground)
            if let suffix {
                Text(suffix)
                    .font(SikaTheme.Typography.sans(12))
                    .foregroundStyle(SikaTheme.Color.mutedForeground)
            }
        }
    }

    private var separator: some View {
        Text("·")
            .font(SikaTheme.Typography.sans(12))
            .foregroundStyle(SikaTheme.Color.mutedForeground)
    }
}
