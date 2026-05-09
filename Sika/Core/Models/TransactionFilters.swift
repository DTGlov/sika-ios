import Foundation

/// In-memory filter state for the Transactions tab.
/// Mirrors web's URL search params (period, type, account, category, bucket,
/// sort, amtMin, amtMax) but lives in @Observable AppState since iOS doesn't
/// have a URL bar. Survives tab switches; resets on cold launch.
///
/// Search is component-local @State, NOT in this struct (matches web).
struct TransactionFilters: Equatable {

    enum Period: String, CaseIterable, Identifiable {
        case cycle      = "cycle"
        case prevCycle  = "prev_cycle"
        case last30     = "last30"
        case last90     = "last90"
        case all        = "all"

        var id: String { rawValue }

        var displayLabel: String {
            switch self {
            case .cycle:     return "This Month"
            case .prevCycle: return "Last Month"
            case .last30:    return "30 Days"
            case .last90:    return "90 Days"
            case .all:       return "All"
            }
        }
    }

    enum SortKey: String, CaseIterable, Identifiable {
        case dateDesc   = "date-desc"
        case dateAsc    = "date-asc"
        case amountDesc = "amount-desc"
        case amountAsc  = "amount-asc"

        var id: String { rawValue }

        var displayLabel: String {
            switch self {
            case .dateDesc:   return "Newest first"
            case .dateAsc:    return "Oldest first"
            case .amountDesc: return "Amount (high→low)"
            case .amountAsc:  return "Amount (low→high)"
            }
        }
    }

    /// Bucket filter — client-side only. Matches a category's bucket name
    /// case-insensitively (BudgetBucket.name is lowercase: "needs"/"wants"/"savings").
    enum BucketName: String, CaseIterable, Identifiable {
        case needs   = "Needs"
        case wants   = "Wants"
        case savings = "Savings"

        var id: String { rawValue }
    }

    var period: Period = .cycle
    var type: TransactionType? = nil
    var accountId: UUID? = nil
    var categoryId: UUID? = nil
    var bucket: BucketName? = nil
    var sort: SortKey = .dateDesc
    var amountMin: Decimal? = nil
    var amountMax: Decimal? = nil

    /// Active filter count for the badge on the Filters button.
    /// Mirror of web's activeFilterCount.
    var activeFilterCount: Int {
        var count = 0
        if type != nil       { count += 1 }
        if accountId != nil  { count += 1 }
        if categoryId != nil { count += 1 }
        if bucket != nil     { count += 1 }
        if amountMin != nil  { count += 1 }
        if amountMax != nil  { count += 1 }
        if sort != .dateDesc { count += 1 }
        return count
    }

    /// Reset to defaults but preserve period (matches web's clearAllFilters).
    mutating func clearAll() {
        let savedPeriod = period
        self = TransactionFilters()
        period = savedPeriod
    }
}
