import Foundation

/// User-defined savings goal. Maps to the goals table on Supabase.
/// Two types: .target (with amount + deadline) and .perpetual (open-ended).
struct Goal: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    let userId: UUID
    let name: String
    let description: String?
    /// Lucide icon name OR emoji glyph (legacy data may have either).
    /// Resolve via IconResolver before display.
    let icon: String?
    /// Color identifier from the goal palette. Format may be hex ("#00D9A3")
    /// or token name. Phase 2 doesn't render goal-specific color; defer.
    let color: String?
    let goalType: GoalType
    let targetAmount: Decimal?
    /// YYYY-MM-DD string (Supabase `date` column has no time component, so the
    /// SDK's default ISO8601 strategy can't decode it as `Date`). Parse on
    /// demand at the comparison site with DateFormatter("yyyy-MM-dd").
    /// Mirrors how Transaction.transactionDate is modeled.
    let deadline: String?
    let accountId: UUID?
    let priority: Int?
    let archived: Bool?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case description
        case icon
        case color
        case goalType = "goal_type"
        case targetAmount = "target_amount"
        case deadline
        case accountId = "account_id"
        case priority
        case archived = "is_archived"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

enum GoalType: String, Codable, CaseIterable {
    case target
    case perpetual
}
