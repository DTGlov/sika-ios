import Foundation

enum AccountType: String, Codable, CaseIterable {
    case general, wallet, cash, savings, investment, other
}

struct Account: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    let userId: UUID
    let name: String
    let accountType: AccountType
    let balance: Decimal?
    let isDefault: Bool?
    let archived: Bool?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case accountType = "account_type"
        case balance
        case isDefault = "is_default"
        case archived
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
