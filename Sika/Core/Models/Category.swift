import Foundation

enum CategoryType: String, Codable, CaseIterable, Identifiable, Equatable, Hashable {
    case expense, income
    /// Reconciliation-only categories created by web's Reconcile flow.
    /// Excluded from the Add-Transaction wizard's grid (which filters to
    /// .expense or .income based on the selected type).
    case adjustment

    var id: String { rawValue }

    var displayLabel: String {
        switch self {
        case .expense:    return "Expense"
        case .income:     return "Income"
        case .adjustment: return "Adjustment"
        }
    }
}

/// Named TransactionCategory to avoid collision with SwiftUI's `Category`
/// namespace risk and to clarify what it is.
struct TransactionCategory: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    let userId: UUID?
    let name: String
    let categoryType: CategoryType
    let bucketId: UUID?
    /// Lucide icon name OR emoji glyph; resolve via IconResolver.
    /// Optional so decoding tolerates rows without an icon column.
    let icon: String?
    /// Soft-archive flag. Mutated by Settings → Categories archive/restore.
    /// `var` so AppState's archive/restore can flip the flag locally
    /// without rebuilding the struct via the codable initializer.
    var archived: Bool?
    let isFavorite: Bool?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case categoryType = "category_type"
        case bucketId = "bucket_id"
        case icon
        case archived
        case isFavorite = "is_favorite"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
