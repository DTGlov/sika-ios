import Foundation

/// Account "kind" for display + bucket-attribution rules.
/// Canonical set is `bank | momo | cash | savings | investment | other`.
///
/// Legacy iOS rows may have `general` or `wallet` strings (Phase 1.5 used
/// those names before web aligned to bank/momo). The custom Decodable
/// init maps legacy → canonical so existing data still decodes.
enum AccountType: String, Codable, CaseIterable, Identifiable, Equatable, Hashable {
    case bank, momo, cash, savings, investment, other

    var id: String { rawValue }

    /// Account types that count as "savings/investment" for bucket math.
    /// Mirrors web's SAVINGS_ACCOUNT_TYPES = Set(['savings', 'investment']).
    static let savingsLike: Set<AccountType> = [.savings, .investment]

    /// Custom decoder: maps legacy `general` → .bank, `wallet` → .momo,
    /// and any unknown raw value → .other. Encodes via the canonical raw value.
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self).lowercased()
        switch raw {
        case "bank", "general":  self = .bank
        case "momo", "wallet":   self = .momo
        case "cash":             self = .cash
        case "savings":          self = .savings
        case "investment":       self = .investment
        default:                 self = .other
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// Account row. Maps to the `accounts` table on Supabase.
///
/// Schema notes:
/// - `opening_balance`: the seed for AccountBalanceEngine. Running balance
///   is fully derived per render — there is NO cached current_balance column.
/// - `is_active`: soft-archive flag. NO restore UI — once false, the row
///   stays in the DB but never surfaces in pickers / lists.
/// - `is_default`: enforced single-default via two-step write at the AppState
///   layer. First account ever created auto-defaults to true.
/// - `icon` / `color`: dead-write columns. Set on save from the type config,
///   never read on iOS (mirrors web's intent).
/// - `sort_order`: presentation order on the Accounts list (creation order).
struct Account: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    let userId: UUID
    let name: String
    let accountType: AccountType
    /// Dead-write — emoji glyph from the type config. iOS writes on save.
    let icon: String?
    /// Dead-write — hex string ("#00D9A3") from the type config.
    let color: String?
    /// Seed for AccountBalanceEngine. Web uses `opening_balance` column.
    /// Optional so decoding tolerates rows where the column hasn't been set yet
    /// (Phase 1.5 wrote to a different column; existing rows may have nil).
    let openingBalance: Decimal?
    /// Single-default flag. Enforced via two-step write.
    let isDefault: Bool?
    /// Soft-archive flag. true (or nil) = visible; false = archived.
    let isActive: Bool?
    /// Presentation order on the Accounts list. Lower first.
    let sortOrder: Int?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId         = "user_id"
        case name
        case accountType    = "account_type"
        case icon
        case color
        case openingBalance = "opening_balance"
        case isDefault      = "is_default"
        case isActive       = "is_active"
        case sortOrder      = "sort_order"
        case createdAt      = "created_at"
        case updatedAt      = "updated_at"
    }
}
