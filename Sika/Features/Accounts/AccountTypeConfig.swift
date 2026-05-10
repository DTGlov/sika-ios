import SwiftUI

/// Display config for an account type. Drives the type tile chrome on the
/// Add/Edit form, the colored dot + emoji on the row card, and the
/// balance text color.
struct AccountTypeConfig: Equatable {
    let label: String
    let colorHex: UInt32
    let emoji: String

    var color: Color { Color(hex: colorHex) }

    /// Hex string for dead-write `accounts.color` column.
    var hexString: String { String(format: "#%06X", colorHex) }
}

enum AccountTypeConfigs {
    /// Mirror of ACCOUNT_TYPE_CONFIG from web (lib/accounts.ts).
    static let map: [AccountType: AccountTypeConfig] = [
        .bank:       AccountTypeConfig(label: "Bank",       colorHex: 0x00D9A3, emoji: "🏦"),
        .momo:       AccountTypeConfig(label: "MoMo",       colorHex: 0xFBBF24, emoji: "📱"),
        .cash:       AccountTypeConfig(label: "Cash",       colorHex: 0xA1A1AA, emoji: "💵"),
        .savings:    AccountTypeConfig(label: "Savings",    colorHex: 0x60A5FA, emoji: "🐷"),
        .investment: AccountTypeConfig(label: "Investment", colorHex: 0x8B5CF6, emoji: "📈"),
        .other:      AccountTypeConfig(label: "Other",      colorHex: 0xF97316, emoji: "👛"),
    ]

    static func config(for type: AccountType) -> AccountTypeConfig {
        map[type] ?? map[.other]!
    }
}
