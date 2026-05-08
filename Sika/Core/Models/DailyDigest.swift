import Foundation
import SwiftUI

/// Categorical type of news story.
/// Mirrors web's DailyCategory union (src/types/daily.ts).
/// Each maps to a brand color and human-readable label per CATEGORY_COLORS
/// / CATEGORY_LABELS.
enum DailyCategory: String, Codable, CaseIterable, Equatable, Hashable {
    case worldMarkets = "world_markets"
    case africaRising = "africa_rising"
    case techTrends   = "tech_trends"
    case youngMoney   = "young_money"

    var label: String {
        switch self {
        case .worldMarkets: return "World Markets"
        case .africaRising: return "Africa Rising"
        case .techTrends:   return "Tech & Trends"
        case .youngMoney:   return "Young Money"
        }
    }

    /// Brand color per category. Hex values from web's CATEGORY_COLORS.
    /// Reuses existing SikaTheme tokens where the hex matches; falls back
    /// to Color(hex:) for the purple value (no existing token).
    var brandColor: Color {
        switch self {
        case .worldMarkets: return SikaTheme.Color.bucketSavings  // #60A5FA blue
        case .africaRising: return SikaTheme.Color.sikaSuccess    // #00D9A3 Sika green
        case .techTrends:   return Color(hex: 0xA78BFA)           // purple (no token)
        case .youngMoney:   return SikaTheme.Color.sikaWarning    // #FBBF24 amber/gold
        }
    }
}

/// One news story within a daily digest.
/// Mirrors web's DailyStory interface.
/// `sourceUrl` is captured but NOT used in v1 — story cards are passive,
/// no tap target. Forward-compat for future SFSafariViewController upgrade.
struct DailyStory: Codable, Identifiable, Equatable, Hashable {
    let id: String
    let category: DailyCategory
    let title: String
    let summary: String
    let sourceName: String
    let sourceUrl: String
    let emoji: String
    let publishedAt: String
    let imageUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, category, title, summary, emoji
        case sourceName  = "source_name"
        case sourceUrl   = "source_url"
        case publishedAt = "published_at"
        case imageUrl    = "image_url"
    }
}

/// Daily digest containing 4 stories (or 1 placeholder when fallback).
/// Mirrors sika_daily_digests table. Shared across all users (no user_id).
/// Hashable so it can drive `.navigationDestination(item:)`.
struct DailyDigest: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    let digestDate: String   // YYYY-MM-DD
    let stories: [DailyStory]
    let isFallback: Bool
    let generatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, stories
        case digestDate  = "digest_date"
        case isFallback  = "is_fallback"
        case generatedAt = "generated_at"
    }
}

/// Per-user read marker. Idempotent on (user_id, digest_date) unique key.
struct UserDailyRead: Codable, Equatable {
    let userId: UUID
    let digestDate: String

    enum CodingKeys: String, CodingKey {
        case userId     = "user_id"
        case digestDate = "digest_date"
    }
}
