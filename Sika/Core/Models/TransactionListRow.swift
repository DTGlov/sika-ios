import Foundation

/// Joined transaction row used by the Transactions tab list.
/// Decoded directly from PostgREST embeds — does NOT modify the existing
/// `Transaction` model (other call sites rely on the simple shape).
///
/// The web query joins `account` (via `account_id`) and `to_account`
/// (via `to_account_id`); iOS schema uses `account_id` (destination/main)
/// and `from_account_id` (source for transfers), so this model joins
/// `account` + `fromAccount`.
///
/// Transfer display: "fromAccount → account" (money flows source → dest).
struct TransactionListRow: Codable, Identifiable, Equatable {
    let id: UUID
    let userId: UUID
    let type: TransactionType
    let amount: Decimal
    let accountId: UUID
    let fromAccountId: UUID?
    let categoryId: UUID?
    let goalId: UUID?
    let paidFromGoalId: UUID?
    let transactionDate: String
    let note: String?
    let generatedFromRecurring: UUID?
    let createdAt: Date?

    // Joined relations (populated by fetchPage's nested select)
    let category: JoinedCategory?
    let account: JoinedAccount?
    let fromAccount: JoinedAccount?

    enum CodingKeys: String, CodingKey {
        case id
        case userId                  = "user_id"
        case type
        case amount
        case accountId               = "account_id"
        case fromAccountId           = "from_account_id"
        case categoryId              = "category_id"
        case goalId                  = "goal_id"
        case paidFromGoalId          = "paid_from_goal_id"
        case transactionDate         = "transaction_date"
        case note
        case generatedFromRecurring  = "generated_from_recurring"
        case createdAt               = "created_at"
        case category
        case account
        case fromAccount             = "from_account"
    }
}

/// Subset of Account exposed via the embed. Only fields the row view reads.
struct JoinedAccount: Codable, Equatable, Identifiable {
    let id: UUID
    let name: String
    let accountType: AccountType?
    let icon: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case accountType = "account_type"
        case icon
    }
}

/// Subset of TransactionCategory + nested BudgetBucket.
struct JoinedCategory: Codable, Equatable, Identifiable {
    let id: UUID
    let name: String
    let icon: String?
    let categoryType: CategoryType?
    let bucket: JoinedBucket?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case icon
        case categoryType = "category_type"
        case bucket
    }
}

/// Subset of BudgetBucket. Lowercase name ("needs" / "wants" / "savings").
struct JoinedBucket: Codable, Equatable, Identifiable {
    let id: UUID
    let name: String
}
