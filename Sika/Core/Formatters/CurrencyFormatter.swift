import Foundation

enum CurrencyFormatter {
    /// Format amount with full precision (matches web's formatCurrency, default mode).
    /// GHS narrow symbol "GH₵" looks awkward — show ISO code instead, matching web behavior.
    static func format(_ amount: Decimal, code: String = "GHS") -> String {
        if code == "GHS" {
            let number = amount.formatted(.number.precision(.fractionLength(2)))
            return "GHS \(number)"
        }
        return amount.formatted(.currency(code: code).precision(.fractionLength(2)))
    }

    /// Format amount in compact notation when ≥1000 (matches web's formatCurrencyCompact).
    /// Compact notation on currency requires iOS 18; falls back to standard format on iOS 17.
    static func compact(_ amount: Decimal, code: String = "GHS") -> String {
        let absValue = abs(NSDecimalNumber(decimal: amount).doubleValue)
        if absValue >= 1000 {
            if #available(iOS 18, *) {
                if code == "GHS" {
                    let number = amount.formatted(.number.notation(.compactName).precision(.fractionLength(0...1)))
                    return "GHS \(number)"
                }
                return amount.formatted(.currency(code: code).notation(.compactName).precision(.fractionLength(0...1)))
            }
        }
        return format(amount, code: code)
    }

    /// Just the symbol (or ISO code for GHS).
    static func symbol(forCode code: String) -> String {
        if code == "GHS" { return "GHS" }
        return CurrencyCatalog.currency(forCode: code)?.symbol ?? code
    }
}
