import Foundation

enum IncomeFrequency: String, Codable, CaseIterable, Identifiable {
    case monthly, weekly, biweekly, irregular

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .monthly: return "Monthly"
        case .weekly: return "Weekly"
        case .biweekly: return "Bi-weekly"
        case .irregular: return "Irregular"
        }
    }

    /// Compact label for narrow chip rendering (matches web's "Bi-wk" abbreviation).
    var compactName: String {
        switch self {
        case .monthly: return "Monthly"
        case .weekly: return "Weekly"
        case .biweekly: return "Bi-wk"
        case .irregular: return "Irregular"
        }
    }

    /// Multiplier to convert this frequency's amount to a monthly equivalent.
    /// Constants match web's lib/income.ts to the digit so totals stay in sync.
    var monthlyMultiplier: Decimal {
        switch self {
        case .monthly: return 1
        case .weekly: return Decimal(string: "4.333")!
        case .biweekly: return Decimal(string: "2.167")!
        case .irregular: return 1
        }
    }

    /// Whether this frequency requires the user to specify an expected_day.
    var requiresExpectedDay: Bool {
        switch self {
        case .monthly, .weekly, .biweekly: return true
        case .irregular: return false
        }
    }

    var expectedDayHint: String {
        switch self {
        case .monthly, .weekly, .biweekly:
            return "Sika will nudge you on this day to confirm the money arrived."
        case .irregular:
            return "Irregular income — Sika won't send reminders. Log it manually when received."
        }
    }
}
