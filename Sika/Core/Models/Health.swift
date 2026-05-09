import Foundation
import SwiftUI

// MARK: - Score

enum HealthLabel: String, Codable, CaseIterable, Equatable {
    case excellent
    case good
    case fair
    case needsAttention = "needs_attention"
    case critical

    var displayName: String {
        switch self {
        case .excellent:      return "Excellent"
        case .good:           return "Good"
        case .fair:           return "Fair"
        case .needsAttention: return "Needs attention"
        case .critical:       return "Critical"
        }
    }

    var color: Color {
        switch self {
        case .excellent:      return Color(hex: 0x00D9A3)
        case .good:           return Color(hex: 0x10B981)
        case .fair:           return Color(hex: 0xFBBF24)
        case .needsAttention: return Color(hex: 0xF97316)
        case .critical:       return Color(hex: 0xF43F5E)
        }
    }

    /// Mirror of web's LABEL_THRESHOLDS — first match wins on score >= min.
    static func from(score: Int) -> HealthLabel {
        switch score {
        case 80...:    return .excellent
        case 60...79:  return .good
        case 40...59:  return .fair
        case 20...39:  return .needsAttention
        default:       return .critical
        }
    }
}

enum HealthFactorId: String, Codable, CaseIterable, Equatable {
    case emergencyCoverage = "emergency_coverage"
    case budgetDiscipline  = "budget_discipline"
    case consistency
    case goalCommitment    = "goal_commitment"
    case diversification

    var displayName: String {
        switch self {
        case .emergencyCoverage: return "Emergency Coverage"
        case .budgetDiscipline:  return "Budget Discipline"
        case .consistency:       return "Consistency"
        case .goalCommitment:    return "Goal Commitment"
        case .diversification:   return "Diversification"
        }
    }

    var weight: Int {
        switch self {
        case .emergencyCoverage: return 25
        case .budgetDiscipline:  return 25
        case .consistency:       return 20
        case .goalCommitment:    return 20
        case .diversification:   return 10
        }
    }
}

struct HealthFactor: Equatable, Identifiable {
    let id: HealthFactorId
    let name: String
    let weight: Int
    let score: Int
    let description: String
    let tip: String?
}

/// Pure value type — not persisted. Computed each load.
struct HealthScore: Equatable {
    let total: Int
    let label: HealthLabel
    let factors: [HealthFactor]
}

// MARK: - Streaks

struct Streaks: Codable, Equatable {
    let userId: UUID
    var loggingCurrent: Int
    var loggingLongest: Int
    var loggingLastDate: String?
    var savingsCurrent: Int
    var savingsLongest: Int
    var savingsLastWeek: String?
    var freezesBanked: Int
    var freezesEarnedTotal: Int
    var loggingMilestonesShown: [Int]
    var savingsMilestonesShown: [Int]
    var createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case userId                  = "user_id"
        case loggingCurrent          = "logging_current"
        case loggingLongest          = "logging_longest"
        case loggingLastDate         = "logging_last_date"
        case savingsCurrent          = "savings_current"
        case savingsLongest          = "savings_longest"
        case savingsLastWeek         = "savings_last_week"
        case freezesBanked           = "freezes_banked"
        case freezesEarnedTotal      = "freezes_earned_total"
        case loggingMilestonesShown  = "logging_milestones_shown"
        case savingsMilestonesShown  = "savings_milestones_shown"
        case createdAt               = "created_at"
        case updatedAt               = "updated_at"
    }
}

// MARK: - Momentum

enum MomentumTier: String, Codable, CaseIterable, Equatable, Identifiable {
    case bronze, silver, gold, platinum, diamond

    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }

    var threshold: Int {
        switch self {
        case .bronze:   return 0
        case .silver:   return 500
        case .gold:     return 2000
        case .platinum: return 5000
        case .diamond:  return 10000
        }
    }

    var color: Color {
        switch self {
        case .bronze:   return Color(hex: 0xCD7F32)
        case .silver:   return Color(hex: 0xC0C0C0)
        case .gold:     return Color(hex: 0xD4AF37)
        case .platinum: return Color(hex: 0xE5E4E2)
        case .diamond:  return Color(hex: 0xB9F2FF)
        }
    }

    /// SF Symbol mapped from web's tier icons.
    var iconName: String {
        switch self {
        case .bronze:   return "medal.fill"
        case .silver:   return "rosette"
        case .gold:     return "trophy.fill"
        case .platinum: return "crown.fill"
        case .diamond:  return "diamond.fill"
        }
    }

    static func from(totalPoints: Int) -> MomentumTier {
        if totalPoints >= MomentumTier.diamond.threshold  { return .diamond }
        if totalPoints >= MomentumTier.platinum.threshold { return .platinum }
        if totalPoints >= MomentumTier.gold.threshold     { return .gold }
        if totalPoints >= MomentumTier.silver.threshold   { return .silver }
        return .bronze
    }
}

enum MomentumEventType: String, Codable {
    case transactionLogged           = "transaction_logged"
    case transactionLoggedViaNudge   = "transaction_logged_via_nudge"
    case goalContribution            = "goal_contribution"
    case accountReconciled           = "account_reconciled"
    case loggingStreak7Days          = "logging_streak_7_days"
    case goalCompleted               = "goal_completed"
    case bucketWithinLimitFullMonth  = "bucket_within_limit_full_month"

    /// Points awarded per event. Mirror of MOMENTUM_AMOUNTS.
    var points: Int {
        switch self {
        case .transactionLogged:          return 2
        case .transactionLoggedViaNudge:  return 5
        case .goalContribution:           return 10
        case .accountReconciled:          return 3
        case .loggingStreak7Days:         return 50
        case .goalCompleted:              return 100
        case .bucketWithinLimitFullMonth: return 75
        }
    }
}

struct Momentum: Codable, Equatable {
    let userId: UUID
    var totalPoints: Int
    var tier: String
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case userId      = "user_id"
        case totalPoints = "total_points"
        case tier
        case updatedAt   = "updated_at"
    }

    var resolvedTier: MomentumTier {
        MomentumTier(rawValue: tier) ?? .bronze
    }
}

// MARK: - Badges

enum BadgeRarity: String, Codable, Equatable {
    case common, rare

    var frameColor: Color {
        switch self {
        case .common: return Color(hex: 0x00D9A3)
        case .rare:   return Color(hex: 0xD4AF37)
        }
    }
}

/// Catalog entry — hardcoded; not persisted.
struct BadgeCatalogEntry: Identifiable, Equatable {
    let id: String
    let name: String
    let description: String
    /// SF Symbol mapped from web's Lucide icon.
    let iconName: String
    let rarity: BadgeRarity
    let sortOrder: Int
}

/// Hardcoded catalog. Mirror of web's BADGES_CATALOG (src/types/badge.ts).
/// Adding a badge requires a coordinated client release on both platforms.
enum BadgeCatalog {
    static let entries: [BadgeCatalogEntry] = [
        BadgeCatalogEntry(
            id: "first_steps",
            name: "First Steps",
            description: "Log your first transaction",
            iconName: "figure.walk",
            rarity: .common,
            sortOrder: 1
        ),
        BadgeCatalogEntry(
            id: "week_warrior",
            name: "Week Warrior",
            description: "Maintain a 7-day logging streak",
            iconName: "flame.fill",
            rarity: .common,
            sortOrder: 2
        ),
        BadgeCatalogEntry(
            id: "goal_getter",
            name: "Goal Getter",
            description: "Complete your first target goal",
            iconName: "target",
            rarity: .common,
            sortOrder: 3
        ),
        BadgeCatalogEntry(
            id: "consistent_saver",
            name: "Consistent Saver",
            description: "Maintain a 4-week savings streak",
            iconName: "dollarsign.circle.fill",
            rarity: .common,
            sortOrder: 4
        ),
        BadgeCatalogEntry(
            id: "century_club",
            name: "Century Club",
            description: "Log 100 total transactions",
            iconName: "number",
            rarity: .rare,
            sortOrder: 5
        ),
        BadgeCatalogEntry(
            id: "month_of_discipline",
            name: "Month of Discipline",
            description: "Maintain a 30-day logging streak",
            iconName: "calendar.badge.checkmark",
            rarity: .rare,
            sortOrder: 6
        ),
        BadgeCatalogEntry(
            id: "seeker",
            name: "Seeker",
            description: "Complete 5 target goals",
            iconName: "safari.fill",
            rarity: .rare,
            sortOrder: 7
        ),
        BadgeCatalogEntry(
            id: "safety_net",
            name: "Safety Net",
            description: "Life Savings reaches 3× your monthly Needs",
            iconName: "shield.fill",
            rarity: .rare,
            sortOrder: 8
        ),
    ]

    static func entry(for id: String) -> BadgeCatalogEntry? {
        entries.first { $0.id == id }
    }

    static let totalCount = 8
}

enum BadgeTrigger: String, CaseIterable, Equatable {
    case transactionLogged  = "transaction_logged"
    case streakUpdated      = "streak_updated"
    case goalCompleted      = "goal_completed"
    case contributionMade   = "contribution_made"
    case accountReconciled  = "account_reconciled"
    case cycleEnded         = "cycle_ended"

    /// Trigger → list of badge IDs to evaluate. Mirror of web's TRIGGER_BADGES.
    var badgeIds: [String] {
        switch self {
        case .transactionLogged:  return ["first_steps", "century_club"]
        case .streakUpdated:      return ["week_warrior", "consistent_saver", "month_of_discipline"]
        case .goalCompleted:      return ["goal_getter", "seeker"]
        case .contributionMade:   return ["safety_net"]
        case .accountReconciled:  return []
        case .cycleEnded:         return ["safety_net"]
        }
    }
}

/// Persisted unlock row (user_badges table).
struct UserBadge: Codable, Equatable, Identifiable {
    let id: UUID
    let userId: UUID
    let badgeId: String
    let unlockedAt: Date
    var celebrationShown: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case userId             = "user_id"
        case badgeId            = "badge_id"
        case unlockedAt         = "unlocked_at"
        case celebrationShown   = "celebration_shown"
    }
}

// MARK: - Composed snapshot

struct HealthSnapshot: Equatable {
    let score: HealthScore?
    let streaks: Streaks?
    let momentum: Momentum?
    let userBadges: [UserBadge]

    static let empty = HealthSnapshot(score: nil, streaks: nil, momentum: nil, userBadges: [])
}
