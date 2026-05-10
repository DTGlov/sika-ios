import Foundation

/// User-defined savings goal. Maps to the goals table on Supabase.
/// Two types: .target (with amount + deadline) and .perpetual (open-ended).
///
/// Cycle system (Phase Goals T1):
/// - `previousGoalId` — link back to the prior cycle's goal when starting fresh
/// - `cycleCount` — 1 for the original, 2+ for subsequent cycles
/// - `completedAt` — set when target is hit (auto) or when payment empties the
///   fund (deferred to T2). Drives Home → "Start next cycle" CTA.
struct Goal: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    let userId: UUID
    let name: String
    let description: String?
    /// Lucide icon name OR emoji glyph (legacy data may have either).
    /// Resolve via IconResolver before display.
    let icon: String?
    /// Color identifier from the goal palette. Hex string ("#00D9A3") OR
    /// token name. Drives card tinting and form CTA color.
    let color: String?
    let goalType: GoalType
    let targetAmount: Decimal?
    /// YYYY-MM-DD string (Supabase `date` column has no time component, so the
    /// SDK's default ISO8601 strategy can't decode it as `Date`). Parse on
    /// demand at the comparison site with DateFormatter("yyyy-MM-dd").
    /// Mirrors how Transaction.transactionDate is modeled.
    let deadline: String?
    /// Account that holds this goal's accumulated funds.
    /// Phase 2 named this `accountId` mapped to `account_id` — the actual DB
    /// column is `funding_account_id`. Renamed in T1.
    let fundingAccountId: UUID?
    let priority: Int?
    let isActive: Bool?
    let isArchived: Bool?
    /// Set when the goal completes (auto via target hit, or via payment that
    /// empties the fund). Drives the "Start next cycle" CTA + completed
    /// section on the list.
    let completedAt: Date?
    /// Backlink to the prior cycle's goal id when this one is a continuation.
    let previousGoalId: UUID?
    /// 1 for original, 2+ for cycles started via "Start next cycle".
    let cycleCount: Int?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId             = "user_id"
        case name
        case description
        case icon
        case color
        case goalType           = "goal_type"
        case targetAmount       = "target_amount"
        case deadline
        case fundingAccountId   = "funding_account_id"
        case priority
        case isActive           = "is_active"
        case isArchived         = "is_archived"
        case completedAt        = "completed_at"
        case previousGoalId     = "previous_goal_id"
        case cycleCount         = "cycle_count"
        case createdAt          = "created_at"
        case updatedAt          = "updated_at"
    }
}

enum GoalType: String, Codable, CaseIterable {
    case target
    case perpetual
}
