import SwiftUI

/// "How this is calculated" transparency card. 3 rows + Info-icon footnote.
///
/// Net row uses + or − prefix (different from hero, which omits + on positive).
/// Footnote: "Account balance corrections (reconciliations) and transfers
/// between your own accounts aren't included."
struct HowCalculatedCard: View {
    let summary: CycleDetailSummary
    let currencyCode: String

    private let goldColor = Color(hex: 0xD4A017)
    private let roseColor = Color(hex: 0xF43F5E)

    private var net: Decimal { summary.net }
    private var isNegative: Bool { net < 0 }

    /// Net row shows + for non-negative, − for negative.
    private var netPrefix: String { isNegative ? "−" : "+" }
    private var netColor: Color { isNegative ? roseColor : goldColor }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("HOW THIS IS CALCULATED")
                .font(.system(size: 11, weight: .medium))
                .tracking(1.2)
                .foregroundStyle(SikaTheme.Color.mutedForeground)

            VStack(spacing: 8) {
                row(label: "Received",
                    text: "+" + CurrencyFormatter.format(summary.totalReceived, code: currencyCode),
                    color: goldColor,
                    weight: .medium,
                    labelColor: SikaTheme.Color.mutedForeground)

                row(label: "Spent",
                    text: "−" + CurrencyFormatter.format(summary.totalSpent, code: currencyCode),
                    color: roseColor,
                    weight: .medium,
                    labelColor: SikaTheme.Color.mutedForeground)

                Divider()
                    .padding(.top, 4)

                row(label: "Net",
                    text: netPrefix + CurrencyFormatter.format(abs(net), code: currencyCode),
                    color: netColor,
                    weight: .semibold,
                    labelColor: SikaTheme.Color.foreground)
            }

            // Transparency footnote
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.system(size: 12))
                    .foregroundStyle(SikaTheme.Color.mutedForeground)
                    .padding(.top, 2)
                Text("Account balance corrections (reconciliations) and transfers between your own accounts aren't included.")
                    .font(SikaTheme.Typography.sans(11))
                    .foregroundStyle(SikaTheme.Color.mutedForeground)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 4)
        }
        .padding(SikaTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(SikaTheme.Color.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(SikaTheme.Color.border, lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private func row(
        label: String,
        text: String,
        color: Color,
        weight: Font.Weight,
        labelColor: Color
    ) -> some View {
        HStack {
            Text(label)
                .font(SikaTheme.Typography.sans(14))
                .foregroundStyle(labelColor)
            Spacer()
            Text(text)
                .font(SikaTheme.Typography.sans(14, weight: weight))
                .monospacedDigit()
                .foregroundStyle(color)
        }
    }
}
