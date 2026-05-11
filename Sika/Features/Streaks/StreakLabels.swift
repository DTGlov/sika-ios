import Foundation

/// Pure label helpers for /streaks. Ports `lastLoggedLabel`,
/// `lastSavedLabel`, `hasLoggedToday`, and `hasSavedThisWeek` from
/// `src/app/(app)/streaks/page.tsx` so the iOS strings line up with
/// the web exactly. Streak dates in Supabase are stored as UTC
/// `YYYY-MM-DD` strings, never as timestamps — all date math here
/// is UTC.
enum StreakLabels {
    // MARK: - Public labels

    /// Returns "Never" | "Today" | "Yesterday" | "{N} days ago"
    static func lastLogged(loggingLastDate: String?) -> String {
        guard let dateStr = loggingLastDate, !dateStr.isEmpty else {
            return "Never"
        }
        if hasLoggedToday(loggingLastDate: dateStr) {
            return "Today"
        }
        guard let date = parseYYYYMMDD(dateStr) else {
            return "Never"
        }
        let days = Int(round(Date().timeIntervalSince(date) / 86400))
        if days == 1 { return "Yesterday" }
        return "\(days) days ago"
    }

    /// Returns "Never" | "This week" | "Last week" | "{N} weeks ago"
    static func lastSaved(savingsLastWeek: String?) -> String {
        guard let dateStr = savingsLastWeek, !dateStr.isEmpty else {
            return "Never"
        }
        if hasSavedThisWeek(savingsLastWeek: dateStr) {
            return "This week"
        }
        guard let date = parseYYYYMMDD(dateStr) else {
            return "Never"
        }
        let weeks = Int(round(Date().timeIntervalSince(date) / 604_800))
        if weeks == 1 { return "Last week" }
        return "\(weeks) weeks ago"
    }

    /// Pure boolean — `logging_last_date == todayUTC`.
    static func hasLoggedToday(loggingLastDate: String?) -> Bool {
        guard let date = loggingLastDate else { return false }
        return date == todayUTC()
    }

    /// Pure boolean — `savings_last_week == mondayUTC` (ISO Monday).
    static func hasSavedThisWeek(savingsLastWeek: String?) -> Bool {
        guard let date = savingsLastWeek else { return false }
        return date == mondayUTC()
    }

    // MARK: - Date helpers (UTC)

    /// Today in UTC as `YYYY-MM-DD`.
    static func todayUTC() -> String {
        Self.yyyyMMddFormatter.string(from: Date())
    }

    /// This week's Monday in UTC as `YYYY-MM-DD`. ISO week (Monday = 1).
    static func mondayUTC() -> String {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let components = calendar.dateComponents(
            [.yearForWeekOfYear, .weekOfYear],
            from: Date()
        )
        let monday = calendar.date(from: components) ?? Date()
        return Self.yyyyMMddFormatter.string(from: monday)
    }

    private static func parseYYYYMMDD(_ str: String) -> Date? {
        Self.yyyyMMddFormatter.date(from: str)
    }

    /// Shared formatter — `YYYY-MM-DD` in UTC, en_US_POSIX locale so
    /// the format string doesn't drift on devices set to non-Gregorian
    /// calendars.
    private static let yyyyMMddFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
}
