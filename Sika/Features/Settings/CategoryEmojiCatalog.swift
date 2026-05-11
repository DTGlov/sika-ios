import Foundation

/// 23-emoji catalog for the Settings → Category form picker.
/// Order matches web's CATEGORY_ICONS constant (audit Section 11.5).
///
/// Stored on `categories.icon` as the literal emoji glyph; `IconResolver`
/// passes through pure-emoji values unchanged (the legacy lucide-name
/// format is also supported on read for seeded defaults).
enum CategoryEmojis {
    static let all: [String] = [
        "🏠", "🛒", "⚡", "💧", "📶", "🚗",
        "🍽️", "💊", "🍕", "🎬", "🛍️", "🔄",
        "🏋️", "✨", "🐷", "📈", "🛡️", "💼",
        "🎁", "⚖️", "📱", "📚", "🎵",
    ]

    /// Fallback used when no icon is selected (form sheet default).
    static let defaultEmoji: String = "🏷️"
}
