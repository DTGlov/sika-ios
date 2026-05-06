import Foundation

struct IncomeSource: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    let userId: UUID
    let name: String
    let amount: Decimal
    let frequency: IncomeFrequency
    let expectedDay: Int?
    let isActive: Bool
    let notes: String?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case amount
        case frequency
        case expectedDay = "expected_day"
        case isActive = "is_active"
        case notes
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    /// This source's amount converted to a monthly equivalent.
    var monthlyEquivalent: Decimal {
        amount * frequency.monthlyMultiplier
    }
}
