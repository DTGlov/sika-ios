import SwiftUI

/// Hardcoded constants for the Goals tab UI.
/// Source-of-truth: web's lib/goals.ts (GOAL_COLORS) + ICON_OPTIONS in
/// goal-modal.tsx + SUGGESTION_PILLS in page.tsx.
enum GoalConstants {
    /// 6 hex colors. Default is index 0 (#00D9A3 green).
    static let colors: [String] = [
        "#00D9A3",  // green (default)
        "#60A5FA",  // blue
        "#FBBF24",  // yellow
        "#F97316",  // orange
        "#A78BFA",  // purple
        "#F43F5E",  // red
    ]

    static let defaultColor: String = colors[0]

    /// 12 emoji glyphs. Stored as glyph in DB, NOT as Lucide keys.
    static let icons: [String] = [
        "🎯", "⭐", "🏠", "🚗", "✈️", "💼",
        "❤️", "🛡️", "⚡", "🎁", "📚", "🎵",
    ]

    static let defaultIcon: String = icons[0]

    /// Empty-state suggestion pills. Tap just opens the create modal —
    /// presentational only (no prefill).
    struct SuggestionPill: Identifiable, Equatable {
        let emoji: String
        let label: String
        var id: String { label }
    }

    static let suggestionPills: [SuggestionPill] = [
        SuggestionPill(emoji: "🎯", label: "Life Savings"),
        SuggestionPill(emoji: "🛡️", label: "Emergency Fund"),
        SuggestionPill(emoji: "🚗", label: "New Car"),
        SuggestionPill(emoji: "✈️", label: "Vacation"),
    ]

    /// Resolves a stored color string to a SwiftUI Color.
    /// Accepts hex like "#00D9A3" or token-name fallback to default.
    static func resolveColor(_ stored: String?) -> Color {
        guard let stored else { return Color(hex: 0x00D9A3) }
        let trimmed = stored.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("#"), trimmed.count == 7 else {
            return Color(hex: 0x00D9A3)
        }
        let hexString = String(trimmed.dropFirst())
        guard let value = UInt32(hexString, radix: 16) else {
            return Color(hex: 0x00D9A3)
        }
        return Color(hex: value)
    }
}
