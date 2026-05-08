import SwiftUI

/// Hero section: period label + big net number + caption.
///
/// Color rules:
/// - Negative net → rose `#F43F5E` with U+2212 prefix
/// - Zero net → muted foreground, no prefix
/// - Positive net → Sika gold `#D4A017`, no prefix (color carries meaning)
struct NetCashFlowHero: View {
    let summary: CycleDetailSummary
    let currencyCode: String

    private var net: Decimal { summary.net }
    private var isNegative: Bool { net < 0 }
    private var isZero: Bool { net == 0 }

    private var netColor: Color {
        if isNegative { return Color(hex: 0xF43F5E) }
        if isZero { return SikaTheme.Color.mutedForeground }
        return Color(hex: 0xD4A017)
    }

    private var prefix: String { isNegative ? "−" : "" }   // U+2212

    private var periodLabel: String {
        let monthDay = DateFormatter()
        monthDay.dateFormat = "MMM d"
        monthDay.locale = Locale(identifier: "en_US_POSIX")

        let monthDayYear = DateFormatter()
        monthDayYear.dateFormat = "MMM d, yyyy"
        monthDayYear.locale = Locale(identifier: "en_US_POSIX")

        let start = monthDay.string(from: summary.cycle.start)
        let end = monthDayYear.string(from: summary.cycle.end)
        return "\(start) — \(end)".uppercased()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(periodLabel)
                .font(.system(size: 11, weight: .medium))
                .tracking(1.2)
                .foregroundStyle(SikaTheme.Color.mutedForeground)
                .padding(.bottom, 4)

            Text("\(prefix)\(CurrencyFormatter.format(abs(net), code: currencyCode))")
                .font(.system(size: 30, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(netColor)

            Text("Net cash flow this cycle")
                .font(SikaTheme.Typography.sans(11))
                .foregroundStyle(SikaTheme.Color.mutedForeground)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
