import SwiftUI

/// "Where Received came from" income list. UNCAPPED — shows all sources.
/// Each row: name + amount. NO percentage, NO icon, NO bar.
/// Container chrome: card bg, rounded-2xl, border. Rows separated by dividers.
struct ReceivedSourcesList: View {
    let rows: [CycleBreakdownRow]
    let currencyCode: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("WHERE RECEIVED CAME FROM")
                .font(.system(size: 11, weight: .medium))
                .tracking(1.2)
                .foregroundStyle(SikaTheme.Color.mutedForeground)

            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
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
