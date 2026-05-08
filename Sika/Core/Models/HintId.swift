import Foundation

/// String-wrapped identifier for dismissible hints.
/// Backed by a String (not a strict enum) because web's type includes
/// a template-literal arm `sunday_recap_${year}_W${week}` that can't
/// be expressed as a Swift enum case.
///
/// Use the static members for known ids (compile-safe), or HintId(rawValue:)
/// to construct from arbitrary strings (e.g. when decoding rows).
struct HintId: RawRepresentable, Hashable, Codable, Equatable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    // MARK: - Known stable ids (mirror src/lib/hints.ts)

    static let recurringIntro             = HintId(rawValue: "recurring_intro")
    static let accountsIntro              = HintId(rawValue: "accounts_intro")
    static let accountsReconcileReminder  = HintId(rawValue: "accounts_reconcile_reminder")
    static let dashboardBucketsIntro      = HintId(rawValue: "dashboard_buckets_intro")
    static let dashboardCardIntro         = HintId(rawValue: "dashboard_card_intro")
    static let cardThemeAvailable         = HintId(rawValue: "card_theme_available")
    static let settingsIncomeSources      = HintId(rawValue: "settings_income_sources")
    static let settingsCategories         = HintId(rawValue: "settings_categories")
    static let goalsIntro                 = HintId(rawValue: "goals_intro")
    static let targetIntro                = HintId(rawValue: "target_intro")
    static let transactionSheetReconcile  = HintId(rawValue: "transaction_sheet_reconcile")
    /// Declared on web in the HintId union but currently has no consumer.
    /// Included here for forward-compat with rows that may exist in the DB.
    static let streaksIntro               = HintId(rawValue: "streaks_intro")

    // MARK: - Dynamic recap id

    /// Constructs the per-week recap id matching web's getRecapHintId() format.
    /// Format: `sunday_recap_<isoYear>_W<isoWeek>` with week zero-padded to 2 digits.
    /// Example: HintId.sundayRecap(year: 2026, week: 19) → "sunday_recap_2026_W19"
    static func sundayRecap(year: Int, week: Int) -> HintId {
        HintId(rawValue: "sunday_recap_\(year)_W\(String(format: "%02d", week))")
    }
}
