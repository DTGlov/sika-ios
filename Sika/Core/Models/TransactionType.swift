import SwiftUI

/// Domain enum for transaction kind. Distinct from `AnalyticsEvent.TransactionType`,
/// which mirrors web's analytics property exactly. Don't merge them.
enum TransactionType: String, Codable, CaseIterable, Identifiable {
    case expense, income, transfer

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .expense: return "Expense"
        case .income: return "Income"
        case .transfer: return "Transfer"
        }
    }

    /// Whether this type requires a category to be selected.
    var requiresCategory: Bool {
        switch self {
        case .expense, .income: return true
        case .transfer: return false
        }
    }

    /// Whether this type uses from_account_id (i.e. is a transfer).
    var isTransfer: Bool { self == .transfer }

    /// Tint color for chips and accents.
    var tint: Color {
        switch self {
        case .expense: return SikaTheme.Color.bucketWants
        case .income: return SikaTheme.Color.bucketNeeds
        case .transfer: return SikaTheme.Color.bucketSavings
        }
    }
}
