import SwiftUI

enum MainTab: String, CaseIterable, Identifiable {
    case home, transactions, accounts, goals, recurring

    var id: String { rawValue }

    var label: String {
        switch self {
        case .home: return "Home"
        case .transactions: return "Transactions"
        case .accounts: return "Accounts"
        case .goals: return "Goals"
        case .recurring: return "Recurring"
        }
    }

    /// SF Symbol for inactive state.
    var iconName: String {
        switch self {
        case .home: return "house"
        case .transactions: return "list.bullet.rectangle"
        case .accounts: return "wallet.bifold"
        case .goals: return "target"
        case .recurring: return "arrow.triangle.2.circlepath"
        }
    }

    /// SF Symbol for active state. Some symbols don't have .fill variants —
    /// for those we return the same icon (color change handles "active" feel).
    var activeIconName: String {
        switch self {
        case .home: return "house.fill"
        case .transactions: return "list.bullet.rectangle.fill"
        case .accounts: return "wallet.bifold.fill"
        case .goals: return "target"
        case .recurring: return "arrow.triangle.2.circlepath"
        }
    }
}
