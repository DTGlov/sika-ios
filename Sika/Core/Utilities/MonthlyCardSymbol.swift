import Foundation

/// Resolves Lucide icon name strings on monthly cards to SF Symbol names.
/// Mirrors web's ICON_MAP in src/components/monthly/monthly-recap.tsx
/// (lines 11-13).
///
/// Web uses 6 icons in monthly: TrendingUp, Flame, Eye, Target, ArrowRight, Sparkles.
/// (Note: insight-strip uses 8; monthly subset is 6 — Zap and RefreshCw absent.)
///
/// Falls back to "sparkles" for unknown values, matching web's
/// `ICON_MAP[card.icon] ?? Sparkles`.
enum MonthlyCardSymbol {
    static let fallback = "sparkles"

    static func resolve(_ lucideName: String?) -> String {
        guard let name = lucideName, !name.isEmpty else { return fallback }
        return mapping[name] ?? fallback
    }

    private static let mapping: [String: String] = [
        "TrendingUp": "chart.line.uptrend.xyaxis",
        "Flame":      "flame.fill",
        "Eye":        "eye.fill",
        "Target":     "target",
        "ArrowRight": "arrow.right",
        "Sparkles":   "sparkles"
    ]
}
