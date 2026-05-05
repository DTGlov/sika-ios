import Foundation

struct Profile: Codable, Identifiable, Equatable {
    let id: UUID
    let fullName: String?
    let email: String?
    let monthlyIncome: Decimal
    let currency: String
    let cycleStartDay: Int
    let needsPercentage: Decimal
    let wantsPercentage: Decimal
    let savingsPercentage: Decimal
    let themePreference: String?
    let cycleCardTheme: String?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case fullName = "full_name"
        case email
        case monthlyIncome = "monthly_income"
        case currency
        case cycleStartDay = "cycle_start_day"
        case needsPercentage = "needs_percentage"
        case wantsPercentage = "wants_percentage"
        case savingsPercentage = "savings_percentage"
        case themePreference = "theme_preference"
        case cycleCardTheme = "cycle_card_theme"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var firstName: String? {
        fullName?.split(separator: " ").first.map(String.init)
    }
}
