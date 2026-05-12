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
    /// TBD verification: `soft_deleted` may not exist on the transactions
    /// table. Optional so decoding tolerates a missing key. If a future
    /// schema check confirms the column is absent, drop this field too
    /// (same class of phantom as `is_active`, which this PR removed).
    let softDeleted: Bool?
    /// Real column — `RecurringService.insertAutoLoggedTransaction` writes
    /// to it successfully, so the schema confirms existence.
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
///
/// Note: the `transactions` table does NOT have an `is_active` column.
/// A previous version of this struct sent `is_active: true`; Supabase
/// rejected every insert with "could not find is_active column". The
/// field is intentionally absent here.
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
    /// EXPENSE rows paid from a target goal's accumulated savings. Wired in T2.
    let paidFromGoalId: UUID?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case type
        case amount
        case accountId = "account_id"
        case toAccountId = "to_account_id"
        case categoryId = "category_id"
        case transactionDate = "transaction_date"
        case note
        case paidFromGoalId = "paid_from_goal_id"
    }
}

/// Update payload for T2's edit flow. Same shape as TransactionDraft minus
/// `user_id` (immutable post-insert). Notably absent: `is_active` — the
/// transactions table has no such column (phantom from yesterday).
struct TransactionUpdate: Encodable {
    let type: TransactionType
    let amount: Decimal
    let accountId: UUID
    let toAccountId: UUID?
    let categoryId: UUID?
    let transactionDate: String
    let note: String?
    let paidFromGoalId: UUID?

    enum CodingKeys: String, CodingKey {
        case type
        case amount
        case accountId = "account_id"
        case toAccountId = "to_account_id"
        case categoryId = "category_id"
        case transactionDate = "transaction_date"
        case note
        case paidFromGoalId = "paid_from_goal_id"
    }
}
