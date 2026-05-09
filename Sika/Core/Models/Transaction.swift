import Foundation

struct Transaction: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    let userId: UUID
    let type: TransactionType
    let amount: Decimal
    /// Source account for transfers; primary account for income/expense/adjustment.
    /// Mirrors web's `account_id` semantics: this is the FROM side of a transfer.
    let accountId: UUID
    /// Destination account for transfers (NULL for non-transfers).
    /// Maps to DB column `to_account_id`. iOS used to call this `fromAccountId`
    /// with mapping `from_account_id` — that column doesn't exist; the field
    /// always decoded to nil. Fixed in T1 follow-up.
    let toAccountId: UUID?
    let categoryId: UUID?
    /// Set on TRANSFER rows that contribute TO a goal. The transfer's
    /// amount is what increased the goal's saved balance.
    let goalId: UUID?
    /// Set on EXPENSE rows that were paid FROM a goal's accumulated
    /// savings. Used to exclude these expenses from cycleSpent and bucket
    /// math (the cost was already accounted for by the original goal
    /// contribution). Mirrors web's `paid_from_goal_id` column.
    let paidFromGoalId: UUID?
    let transactionDate: String
    let note: String?
    /// DEPRECATED: transactions table has no is_active column. Optional so
    /// decoding tolerates the missing key. Remove when no callsites set it.
    let isActive: Bool?
    let softDeleted: Bool?
    let generatedFromRecurring: UUID?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case type
        case amount
        case accountId = "account_id"
        case toAccountId = "to_account_id"
        case categoryId = "category_id"
        case goalId = "goal_id"
        case paidFromGoalId = "paid_from_goal_id"
        case transactionDate = "transaction_date"
        case note
        case isActive = "is_active"
        case softDeleted = "soft_deleted"
        case generatedFromRecurring = "generated_from_recurring"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    /// Local-only flag: true when this row is an optimistic insert not yet confirmed.
    /// Not in CodingKeys — never decoded from or encoded to Supabase.
    var isPending: Bool = false

    var displayAmount: Decimal { amount }
}

/// Insert payload — matches what the form writes to the server.
struct TransactionDraft: Encodable {
    let userId: UUID
    let type: TransactionType
    let amount: Decimal
    /// Source account (FROM side of transfers).
    let accountId: UUID
    /// Destination account (TO side of transfers; nil otherwise).
    let toAccountId: UUID?
    let categoryId: UUID?
    let transactionDate: String
    let note: String?
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case type
        case amount
        case accountId = "account_id"
        case toAccountId = "to_account_id"
        case categoryId = "category_id"
        case transactionDate = "transaction_date"
        case note
        case isActive = "is_active"
    }
}
