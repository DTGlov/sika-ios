import Foundation

/// Lightweight projections of joined relations used by list-page fetches.
/// Decoded from PostgREST embeds — distinct from the full models so adding
/// fields to Account/TransactionCategory/BudgetBucket doesn't ripple.
///
/// Shared across tabs (currently used by the Recurring tab; future Transactions
/// tab list will reuse). Lives outside any single Feature folder so multiple
/// surfaces can decode the same shape.

/// Subset of Account exposed via embed.
struct JoinedAccountRef: Codable, Equatable, Hashable, Identifiable {
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
struct JoinedCategoryRef: Codable, Equatable, Hashable, Identifiable {
    let id: UUID
    let name: String
    let icon: String?
    let categoryType: CategoryType?
    let bucket: JoinedBucketRef?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case icon
        case categoryType = "category_type"
        case bucket
    }
}

/// Subset of BudgetBucket. Lowercase canonical name ("needs"/"wants"/"savings").
struct JoinedBucketRef: Codable, Equatable, Hashable, Identifiable {
    let id: UUID
    let name: String
}
