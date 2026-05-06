import Foundation

enum CategoryType: String, Codable {
    case expense, income
}

/// Named TransactionCategory to avoid collision with SwiftUI's `Category`
/// namespace risk and to clarify what it is.
struct TransactionCategory: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    let userId: UUID?
    let name: String
    let categoryType: CategoryType
    let bucketId: UUID?
    let archived: Bool?
    let isFavorite: Bool?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case categoryType = "category_type"
        case bucketId = "bucket_id"
        case archived
        case isFavorite = "is_favorite"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
