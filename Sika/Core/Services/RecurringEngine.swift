import Foundation

/// Pure date-math helpers for recurring transactions.
/// Mirror of web's frequency engine in src/lib/recurring.ts.
///
/// Convention notes:
/// - `scheduleDay` semantics depend on frequency:
///   - weekly/biweekly: day-of-week with web convention (0=Sun ... 6=Sat).
///     Apple's Calendar uses 1=Sun ... 7=Sat — we subtract 1 to align.
///   - monthly: day-of-month, 1...28 OR -1 (meaning "last day of month")
///   - daily / yearly: ignored (yearly uses startDate's month/day)
enum RecurringDateMath {

    /// Computes the next occurrence on or after `from`.
    /// Returns nil if past endDate or if start_date can't be parsed.
    /// Mirror of web's getNextDueDate.
    static func nextDueDate(
        for rec: RecurringTransaction,
        from: Date
    ) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current

        guard let startDate = formatter.date(from: rec.startDate) else { return nil }

        // If `from` is before start_date, anchor at start_date
        let anchorDate = max(from, startDate)

        // If past end_date, no more occurrences
        if let endDateStr = rec.endDate,
           let endDate = formatter.date(from: endDateStr),
           anchorDate > endDate {
            return nil
        }

        let result: Date?

        switch rec.frequency {
        case .daily:
            // Daily occurrences from start_date onward
            result = anchorDate

        case .weekly:
            guard let scheduleDay = rec.scheduleDay else { return nil }
            result = nextWeekday(scheduleDay: scheduleDay, from: anchorDate, calendar: calendar)

        case .biweekly:
            guard let scheduleDay = rec.scheduleDay else { return nil }
            result = nextBiweeklyDate(
                scheduleDay: scheduleDay,
                from: anchorDate,
                startDate: startDate,
                calendar: calendar
            )

        case .monthly:
            guard let scheduleDay = rec.scheduleDay else { return nil }
            result = nextMonthlyDate(
                scheduleDay: scheduleDay,
                from: anchorDate,
                calendar: calendar
            )

        case .yearly:
            result = nextYearlyDate(
                from: anchorDate,
                startDate: startDate,
                calendar: calendar
            )
        }

        // Final end_date check
        if let result, let endDateStr = rec.endDate,
           let endDate = formatter.date(from: endDateStr),
           result > endDate {
            return nil
        }

        return result
    }

    // MARK: - Frequency-specific helpers

    /// Next occurrence of the given day-of-week (0=Sun ... 6=Sat, web convention)
    /// on or after `from`. Returns `from` if it's already on the target weekday.
    private static func nextWeekday(
        scheduleDay: Int,
        from: Date,
        calendar: Calendar
    ) -> Date {
        // Apple's weekday is 1=Sun ... 7=Sat; subtract 1 to match web's 0=Sun ... 6=Sat.
        let fromWeekday = calendar.component(.weekday, from: from) - 1
        let daysToAdd = (scheduleDay - fromWeekday + 7) % 7
        return calendar.date(byAdding: .day, value: daysToAdd, to: from) ?? from
    }

    /// Biweekly: next occurrence of the given day-of-week, but only on weeks
    /// that align with the start_date's biweekly phase.
    private static func nextBiweeklyDate(
        scheduleDay: Int,
        from: Date,
        startDate: Date,
        calendar: Calendar
    ) -> Date {
        // Find the next weekday match, then check phase
        var candidate = nextWeekday(
            scheduleDay: scheduleDay,
            from: from,
            calendar: calendar
        )

        // Days since start_date; biweekly phase is days % 14
        let candidateDay = calendar.startOfDay(for: candidate)
        let startDay = calendar.startOfDay(for: startDate)
        let daysSinceStart = calendar.dateComponents([.day], from: startDay, to: candidateDay).day ?? 0
        let phaseDays = ((daysSinceStart % 14) + 14) % 14  // normalize negative

        // If candidate falls on an "off" week, push forward 7 days
        if phaseDays >= 7 {
            candidate = calendar.date(byAdding: .day, value: 7, to: candidate) ?? candidate
        }

        return candidate
    }

    /// Next occurrence of day-of-month (1...28 or -1 for last day) on or after `from`.
    private static func nextMonthlyDate(
        scheduleDay: Int,
        from: Date,
        calendar: Calendar
    ) -> Date {
        // Try this month first
        if let candidate = monthlyDate(
            in: from,
            scheduleDay: scheduleDay,
            calendar: calendar
        ), candidate >= calendar.startOfDay(for: from) {
            return candidate
        }

        // Otherwise try next month
        guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: from),
              let candidate = monthlyDate(
                  in: nextMonth,
                  scheduleDay: scheduleDay,
                  calendar: calendar
              ) else {
            return from  // fallback (shouldn't happen)
        }
        return candidate
    }

    /// Returns the date of `scheduleDay` (day-of-month) within the month
    /// containing `reference`. -1 means last day of month. Caps day at month
    /// length so e.g. day=31 in February yields Feb 28/29.
    private static func monthlyDate(
        in reference: Date,
        scheduleDay: Int,
        calendar: Calendar
    ) -> Date? {
        let yearMonth = calendar.dateComponents([.year, .month], from: reference)
        guard let year = yearMonth.year, let month = yearMonth.month else { return nil }
        guard let monthStart = calendar.date(from: DateComponents(year: year, month: month, day: 1))
            else { return nil }
        guard let monthRange = calendar.range(of: .day, in: .month, for: monthStart) else {
            return nil
        }
        let daysInMonth = monthRange.upperBound - 1

        let day: Int
        if scheduleDay == -1 {
            day = daysInMonth
        } else {
            day = min(max(scheduleDay, 1), daysInMonth)
        }

        return calendar.date(from: DateComponents(year: year, month: month, day: day))
    }

    /// Next yearly occurrence: same month/day as startDate, in the year
    /// matching or after `from`.
    private static func nextYearlyDate(
        from: Date,
        startDate: Date,
        calendar: Calendar
    ) -> Date? {
        let startMonthDay = calendar.dateComponents([.month, .day], from: startDate)
        let fromYear = calendar.component(.year, from: from)

        var thisYearComponents = DateComponents()
        thisYearComponents.year = fromYear
        thisYearComponents.month = startMonthDay.month
        thisYearComponents.day = startMonthDay.day

        guard let thisYear = calendar.date(from: thisYearComponents) else { return nil }

        if calendar.startOfDay(for: thisYear) >= calendar.startOfDay(for: from) {
            return thisYear
        }

        thisYearComponents.year = fromYear + 1
        return calendar.date(from: thisYearComponents)
    }
}
