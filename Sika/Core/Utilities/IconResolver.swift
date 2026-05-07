import Foundation

/// Resolves icon strings stored in the database to displayable emojis.
///
/// The database has three formats due to organic schema drift:
/// 1. Lucide icon names (current standard): "home", "shopping-cart", "zap"
/// 2. Direct emoji glyphs (legacy): "🏦", "🐷", "👛"
/// 3. nil or empty
///
/// This resolver handles all three, falling back to "📋" (clipboard)
/// for unknown values.
enum IconResolver {
    static let fallback = "📋"

    /// Resolves an icon string to an emoji glyph for display.
    /// Returns nil if the input is nil/empty so callers can apply their own
    /// fallback (e.g. account-type-based emoji map).
    static func resolveOrNil(_ icon: String?) -> String? {
        guard let icon, !icon.isEmpty else { return nil }
        if icon.isPureEmoji { return icon }
        return Self.lucideToEmoji[icon]
    }

    /// Resolves an icon string to an emoji glyph, falling back to clipboard.
    static func resolve(_ icon: String?) -> String {
        resolveOrNil(icon) ?? fallback
    }

    /// Map of Lucide icon names → display emojis.
    /// Covers the common icons used by Sika's category, account, and goal seeds.
    private static let lucideToEmoji: [String: String] = [
        // Money & finance
        "banknote": "💵",
        "wallet": "👛",
        "credit-card": "💳",
        "piggy-bank": "🐷",
        "landmark": "🏦",
        "coins": "🪙",
        "dollar-sign": "💰",
        "trending-up": "📈",
        "trending-down": "📉",
        "scale": "⚖️",
        "scale-3d": "⚖️",

        // Home & life
        "home": "🏠",
        "key": "🔑",
        "bed": "🛏️",
        "sofa": "🛋️",
        "shopping-cart": "🛒",
        "shopping-bag": "🛍️",
        "package": "📦",

        // Transport
        "car": "🚗",
        "plane": "✈️",
        "bus": "🚌",
        "bike": "🚲",
        "fuel": "⛽",
        "map-pin": "📍",
        "navigation": "🧭",

        // Food
        "utensils": "🍴",
        "coffee": "☕",
        "pizza": "🍕",
        "apple": "🍎",
        "beer": "🍺",

        // Bills & utilities
        "zap": "⚡️",
        "droplet": "💧",
        "droplets": "💧",
        "flame": "🔥",
        "wifi": "📶",
        "phone": "📱",
        "smartphone": "📱",

        // Health & fitness
        "heart": "❤️",
        "heart-pulse": "💗",
        "dumbbell": "💪",
        "pill": "💊",
        "stethoscope": "🩺",
        "activity": "💗",

        // Work & study
        "briefcase": "💼",
        "book": "📚",
        "book-open": "📖",
        "books": "📚",
        "graduation-cap": "🎓",
        "laptop": "💻",
        "monitor": "🖥️",

        // Entertainment
        "music": "🎵",
        "music-2": "🎵",
        "film": "🎬",
        "clapperboard": "🎬",
        "gamepad-2": "🎮",
        "headphones": "🎧",
        "camera": "📷",
        "tv": "📺",

        // Misc
        "gift": "🎁",
        "star": "⭐",
        "sparkles": "✨",
        "rocket": "🚀",
        "shield": "🛡️",
        "target": "🎯",
        "umbrella": "☂️",
        "bell": "🔔"
    ]
}

private extension String {
    /// True if every Unicode scalar in the string is an emoji presentation
    /// character or a known emoji range. Tolerates compound emojis (skin
    /// tones, ZWJ joiners, variation selectors).
    var isPureEmoji: Bool {
        guard !isEmpty else { return false }
        return unicodeScalars.allSatisfy { scalar in
            scalar.properties.isEmojiPresentation
                || scalar.properties.isEmoji
                || (0x1F1E6...0x1F1FF).contains(scalar.value)
                || (0xFE00...0xFE0F).contains(scalar.value)
                || scalar.value == 0x200D
        }
    }
}
