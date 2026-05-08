import Foundation

/// Type of insight card within a monthly recap.
/// Mirrors web's MonthlyCardType union (src/types/monthly.ts).
enum MonthlyCardType: String, Codable, CaseIterable, Equatable, Hashable {
    case headline
    case win
    case sideEye   = "side_eye"
    case trend
    case goalCheck = "goal_check"
    case nextMove  = "next_move"
    case reflection
}

/// Accent color treatment for monthly cards.
/// Same shape as Phase 5a's InsightAccent but kept SEPARATE for type safety
/// and future divergence (e.g. monthly might add new accents).
enum MonthlyAccent: String, Codable, CaseIterable, Equatable, Hashable {
    case green
    case amber
    case red
    case blue
    case neutral
}

/// One card in a monthly recap. 5–7 of these per recap.
/// `stat` reuses Phase 5a's InsightStat (label + value pair) — same shape on web.
struct MonthlyCard: Codable, Identifiable, Equatable, Hashable {
    let id: String
    let type: MonthlyCardType
    let headline: String
    let body: String
    let accentColor: MonthlyAccent?
    let stat: InsightStat?
    /// Lucide icon name; resolve via MonthlyCardSymbol.resolve(_:)
    let icon: String?

    enum CodingKeys: String, CodingKey {
        case id, type, headline, body, stat, icon
        case accentColor = "accent_color"
    }
}

/// Database row from the monthly_recaps table.
/// recap_data is the JSONB column containing [MonthlyCard].
///
/// Note: web's TS type does not include `dismissed_at` (it dismisses purely
/// via viewed_at). The iOS banner adds an X dismiss path. If the column
/// doesn't exist on the table, `dismissedAt` decodes as nil (Optional),
/// and the dismiss UPDATE may silently fail — which still produces correct
/// optimistic local-clear behavior for the session.
struct MonthlyRecap: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    let userId: UUID
    let monthStart: String   // YYYY-MM-DD
    let monthEnd: String     // YYYY-MM-DD
    let recapData: [MonthlyCard]
    let generatedAt: Date
    let viewedAt: Date?
    let sharedAt: Date?
    let dismissedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId      = "user_id"
        case monthStart  = "month_start"
        case monthEnd    = "month_end"
        case recapData   = "recap_data"
        case generatedAt = "generated_at"
        case viewedAt    = "viewed_at"
        case sharedAt    = "shared_at"
        case dismissedAt = "dismissed_at"
    }
}
