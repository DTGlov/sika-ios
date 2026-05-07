import Foundation

struct Transaction: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    let userId: UUID
    let type: TransactionType
    let amount: Decimal
    let accountId: UUID
    let fromAccountId: UUID?
    let categoryId: UUID?
    let goalId: UUID?
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
        case fromAccountId = "from_account_id"
        case categoryId = "category_id"
        case goalId = "goal_id"
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
    let accountId: UUID
    let fromAccountId: UUID?
    let categoryId: UUID?
    let transactionDate: String
    let note: String?
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case type
        case amount
        case accountId = "account_id"
        case fromAccountId = "from_account_id"
        case categoryId = "category_id"
        case transactionDate = "transaction_date"
        case note
        case isActive = "is_active"
    }
}
