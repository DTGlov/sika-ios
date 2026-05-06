import SwiftUI

/// The "₵0" or "₵123" amount display at the top of step 1.
/// Uses Geist Mono Bold at large size for tabular figures so layout doesn't
/// shift as digit count changes.
struct AmountDisplay: View {
    let amountString: String

    var body: some View {
        HStack(spacing: SikaTheme.Spacing.xs) {
            Text(SikaTheme.Symbols.cediSign)
                .font(SikaTheme.Typography.displayDigit(56))
                .foregroundStyle(SikaTheme.Color.mutedForeground)
            Text(amountString.isEmpty ? "0" : amountString)
                .font(SikaTheme.Typography.displayDigit(56))
                .foregroundStyle(SikaTheme.Color.foreground)
        }
    }
}
