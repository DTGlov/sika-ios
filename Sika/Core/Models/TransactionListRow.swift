import Foundation

/// Joined transaction row used by the Transactions tab list.
/// Decoded directly from PostgREST embeds — does NOT modify the existing
/// `Transaction` model (other call sites rely on the simple shape).
///
/// Schema (matches web): `account_id` is the source/FROM side; `to_account_id`
/// is the destination/TO side for transfers. The list joins both.
///
/// Transfer display: "account → toAccount" (money flows source → destination).
struct TransactionListRow: Codable, Identifiable, Equatable {
    let id: UUID
    let userId: UUID
    let type: TransactionType
    let amount: Decimal
    let accountId: UUID
    let toAccountId: UUID?
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
    let toAccount: JoinedAccount?

    enum CodingKeys: String, CodingKey {
        case id
        case userId                  = "user_id"
        case type
        case amount
        case accountId               = "account_id"
        case toAccountId             = "to_account_id"
        case categoryId              = "category_id"
        case goalId                  = "goal_id"
        case paidFromGoalId          = "paid_from_goal_id"
        case transactionDate         = "transaction_date"
        case note
        case generatedFromRecurring  = "generated_from_recurring"
        case createdAt               = "created_at"
        case category
        case account
        case toAccount               = "to_account"
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
