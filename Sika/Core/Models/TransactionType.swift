import SwiftUI

/// Domain enum for transaction kind. Distinct from `AnalyticsEvent.TransactionType`,
/// which mirrors web's analytics property exactly. Don't merge them.
enum TransactionType: String, Codable, CaseIterable, Identifiable {
    case expense, income, transfer, adjustment

    var id: String { rawValue }

    /// Types the user can create from the Add-Transaction wizard.
    /// `.adjustment` exists on the model so decoding tolerates rows created
    /// by web's Reconcile flow, but is never offered as a wizard option.
    static let userCreatable: [TransactionType] = [.expense, .income, .transfer]

    var displayName: String {
        switch self {
        case .expense: return "Expense"
        case .income: return "Income"
        case .transfer: return "Transfer"
        case .adjustment: return "Adjustment"
        }
    }

    /// Whether this type requires a category to be selected.
    var requiresCategory: Bool {
        switch self {
        case .expense, .income, .adjustment: return true
        case .transfer: return false
        }
    }

    /// Whether this type uses to_account_id (i.e. is a transfer).
    var isTransfer: Bool { self == .transfer }

    /// Tint color for chips and accents.
    var tint: Color {
        switch self {
        case .expense: return SikaTheme.Color.bucketWants
        case .income: return SikaTheme.Color.bucketNeeds
        case .transfer: return SikaTheme.Color.bucketSavings
        case .adjustment: return SikaTheme.Color.mutedForeground
        }
    }
}
