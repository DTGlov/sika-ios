import Foundation

/// Frequency cadence for recurring transactions.
/// Mirrors web's RecurringFrequency type union.
enum RecurringFrequency: String, Codable, CaseIterable, Equatable {
    case daily, weekly, biweekly, monthly, yearly
}

/// Scheduled expense/income rule. Mirrors recurring_transactions table.
///
/// schedule_day semantics depend on frequency:
/// - weekly/biweekly: day-of-week (0=Sun, 6=Sat — web convention)
/// - monthly: day-of-month (1-28 or -1 for "last day of month")
/// - daily: ignored
/// - yearly: ignored (uses startDate's month/day)
///
/// auto_log=true rules: silently materialized as transactions on first session
/// auto_log=false rules: surface as PendingRecurringCard for user confirmation
///
/// last_generated_date is the "I handled this" signal. After confirm or skip,
/// bumps forward to prevent re-prompt for the same period.
struct RecurringTransaction: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    let userId: UUID
    let accountId: UUID
    let categoryId: UUID?
    let type: TransactionType    // .expense | .income (income filtered from Home)
    let amount: Decimal
    let note: String?
    let frequency: RecurringFrequency
    let startDate: String        // YYYY-MM-DD
    let endDate: String?         // YYYY-MM-DD or nil for no end
    let scheduleDay: Int?
    let autoLog: Bool
    let lastGeneratedDate: String?  // YYYY-MM-DD or nil
    let isActive: Bool
    let isPaused: Bool
    let createdAt: Date?
    let updatedAt: Date?

    /// Joined via PostgREST embed by RecurringService.fetchAll.
    /// Nil for fetches that don't request the embed (e.g. dueRecurring).
    let account: JoinedAccountRef?
    /// Joined via PostgREST embed by RecurringService.fetchAll.
    let category: JoinedCategoryRef?

    enum CodingKeys: String, CodingKey {
        case id
        case userId             = "user_id"
        case accountId          = "account_id"
        case categoryId         = "category_id"
        case type
        case amount
        case note
        case frequency
        case startDate          = "start_date"
        case endDate            = "end_date"
        case scheduleDay        = "schedule_day"
        case autoLog            = "auto_log"
        case lastGeneratedDate  = "last_generated_date"
        case isActive           = "is_active"
        case isPaused           = "is_paused"
        case createdAt          = "created_at"
        case updatedAt          = "updated_at"
        case account
        case category
    }
}

/// In-memory wrapper produced by RecurringService.
/// dueDates is oldest-first; the UI shows only `dueDates.last`.
struct PendingRecurring: Identifiable, Equatable {
    let recurring: RecurringTransaction
    let dueDates: [String]   // YYYY-MM-DD, oldest-first

    var id: UUID { recurring.id }

    /// Latest missed due date (the one shown on the card and used by
    /// Confirm/Skip handlers).
    var latestDueDate: String? { dueDates.last }
}
