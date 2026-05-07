import SwiftUI

/// One half of the SpendCardPair. Title + currency code + amount + optional delta.
struct SpendCard: View {
    let title: String
    let amount: Decimal
    var currencyCode: String = "GHS"
    var deltaPercent: Decimal? = nil
    var deltaLabel: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: SikaTheme.Spacing.sm) {
            Text(title.uppercased())
                .font(SikaTheme.Typography.sans(11, weight: .semibold))
                .foregroundStyle(SikaTheme.Color.mutedForeground)
                .tracking(1)

            Text(currencyCode)
                .font(SikaTheme.Typography.sans(11))
                .foregroundStyle(SikaTheme.Color.mutedForeground)

            Text(CurrencyFormatter.compactRaw(amount))
                .font(SikaTheme.Typography.displayDigit(28))
                .foregroundStyle(SikaTheme.Color.foreground)

            if let deltaPercent, let deltaLabel {
                deltaRow(percent: deltaPercent, label: deltaLabel)
            }

            Spacer(minLength: 0)
        }
        .padding(SikaTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 140)
        .background(SikaTheme.Color.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func deltaRow(percent: Decimal, label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: percent > 0 ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 11, weight: .semibold))
            Text("\(formatPercent(percent))% \(label)")
                .font(SikaTheme.Typography.sans(11, weight: .semibold))
        }
        .foregroundStyle(percent > 0
            ? SikaTheme.Color.sikaWarning
            : SikaTheme.Color.sikaSuccess)
    }

    private func formatPercent(_ value: Decimal) -> String {
        let absValue = NSDecimalNumber(decimal: abs(value)).intValue
        return String(absValue)
    }
}
