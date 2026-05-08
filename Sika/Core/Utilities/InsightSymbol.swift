import Foundation

/// Resolves Lucide icon name strings (from the AI-generated insight)
/// to SF Symbol names for SwiftUI rendering.
///
/// Mirrors web's ICON_MAP in src/components/dashboard/insight-strip.tsx.
/// The web ICON_MAP defines 8 Lucide icons used by the AI prompt:
/// TrendingUp, Flame, Eye, Target, Sparkles, ArrowRight, Zap, RefreshCw.
///
/// Falls back to "sparkles" for unknown values — matches web's
/// `ICON_MAP[insight.icon] ?? Sparkles` fallback.
enum InsightSymbol {
    static let fallback = "sparkles"

    static func resolve(_ lucideName: String?) -> String {
        guard let name = lucideName, !name.isEmpty else { return fallback }
        return mapping[name] ?? fallback
    }

    /// Lucide → SF Symbol mapping. Names match web's ICON_MAP keys.
    private static let mapping: [String: String] = [
        "TrendingUp": "chart.line.uptrend.xyaxis",
        "Flame":      "flame.fill",
        "Eye":        "eye.fill",
        "Target":     "target",
        "Sparkles":   "sparkles",
        "ArrowRight": "arrow.right",
        "Zap":        "bolt.fill",
        "RefreshCw":  "arrow.clockwise"
    ]
}
