import Foundation

/// Internal-only model for the budget_buckets table. Used to resolve
/// category.bucketId → bucket name (needs/wants/savings) for spend grouping.
///
/// Display info (color, sort order, description) is hardcoded in
/// BucketSpendCalculator.buckets — matches web's BUCKET_CONFIG.
struct BudgetBucket: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    let userId: UUID
    /// Lowercase canonical name: "needs", "wants", or "savings".
    let name: String
    let sortOrder: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case sortOrder = "sort_order"
    }
}
