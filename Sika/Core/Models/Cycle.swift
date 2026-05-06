import Foundation

/// A single cycle window — derived live from a cycleStartDay and a reference date.
/// Mirrors web's CycleWindow exactly. Source of truth: src/lib/cycle.ts.
struct Cycle: Equatable, Hashable {
    let start: Date
    let end: Date
    let label: String
    let isCurrent: Bool

    /// String form of start date in yyyy-MM-dd, used as a stable cycle identifier.
    /// Matches web's startDateStr field.
    var startDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        return formatter.string(from: start)
    }
}

enum CycleCalculator {
    /// Returns the cycle window containing the given date.
    /// Equivalent to web's getCycleForDate.
    ///
    /// Algorithm:
    ///   if date.day >= cycleStartDay: cycle started this month
    ///   else: cycle started LAST month, clamped to last day if last month is shorter
    static func cycle(forDate date: Date, cycleStartDay: Int, calendar: Calendar = .current) -> Cycle {
        let normalizedToday = calendar.startOfDay(for: Date())

        let components = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = components.year,
              let month = components.month,
              let day = components.day else {
            return Cycle(start: date, end: date, label: "—", isCurrent: false)
        }

        let cycleStart: Date
        if day >= cycleStartDay {
            cycleStart = calendar.date(from: DateComponents(
                year: year, month: month, day: cycleStartDay
            )) ?? date
        } else {
            let lastMonthDate = calendar.date(byAdding: .month, value: -1, to: date) ?? date
            let lastMonthComponents = calendar.dateComponents([.year, .month], from: lastMonthDate)
            guard let lastMonthYear = lastMonthComponents.year,
                  let lastMonth = lastMonthComponents.month else {
                return Cycle(start: date, end: date, label: "—", isCurrent: false)
            }

            let daysInLastMonth: Int
            if let firstOfThis = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
               let lastDayOfLast = calendar.date(byAdding: .day, value: -1, to: firstOfThis) {
                daysInLastMonth = calendar.component(.day, from: lastDayOfLast)
            } else {
                daysInLastMonth = 31
            }

            let clampedDay = min(cycleStartDay, daysInLastMonth)
            cycleStart = calendar.date(from: DateComponents(
                year: lastMonthYear, month: lastMonth, day: clampedDay
            )) ?? date
        }

        let cycleEnd: Date = {
            guard let plusOneMonth = calendar.date(byAdding: .month, value: 1, to: cycleStart),
                  let minusOneDay = calendar.date(byAdding: .day, value: -1, to: plusOneMonth) else {
                return cycleStart
            }
            return calendar.startOfDay(for: minusOneDay)
        }()

        let normalizedStart = calendar.startOfDay(for: cycleStart)
        let isCurrent = normalizedToday >= normalizedStart && normalizedToday <= cycleEnd

        return Cycle(
            start: normalizedStart,
            end: cycleEnd,
            label: buildLabel(start: normalizedStart, end: cycleEnd, cycleStartDay: cycleStartDay),
            isCurrent: isCurrent
        )
    }

    /// Returns the cycle window N positions away from the cycle containing referenceDate.
    /// offset=0 → same cycle, offset=-1 → previous, offset=+1 → next.
    /// Equivalent to web's getCycleAtOffset.
    static func cycle(atOffset offset: Int, fromDate referenceDate: Date,
                      cycleStartDay: Int, calendar: Calendar = .current) -> Cycle {
        let current = cycle(forDate: referenceDate, cycleStartDay: cycleStartDay, calendar: calendar)
        guard let shiftedStart = calendar.date(byAdding: .month, value: offset, to: current.start) else {
            return current
        }
        return cycle(fromStartDate: shiftedStart, cycleStartDay: cycleStartDay, calendar: calendar)
    }

    /// Reconstruct a cycle from an explicit start date (e.g. parsed from a stored
    /// startDateString). Equivalent to web's getCycleFromStartDate.
    static func cycle(fromStartDate startDate: Date, cycleStartDay: Int,
                      calendar: Calendar = .current) -> Cycle {
        let normalizedStart = calendar.startOfDay(for: startDate)
        let cycleEnd: Date = {
            guard let plusOneMonth = calendar.date(byAdding: .month, value: 1, to: normalizedStart),
                  let minusOneDay = calendar.date(byAdding: .day, value: -1, to: plusOneMonth) else {
                return normalizedStart
            }
            return calendar.startOfDay(for: minusOneDay)
        }()
        let today = calendar.startOfDay(for: Date())
        let isCurrent = today >= normalizedStart && today <= cycleEnd

        return Cycle(
            start: normalizedStart,
            end: cycleEnd,
            label: buildLabel(start: normalizedStart, end: cycleEnd, cycleStartDay: cycleStartDay),
            isCurrent: isCurrent
        )
    }

    /// Parse a "yyyy-MM-dd" cycle identifier back into a Date. Returns nil on bad input.
    /// Equivalent to web's parseCycleParam.
    static func parseStartDateString(_ value: String) -> Date? {
        let pattern = #"^\d{4}-\d{2}-\d{2}$"#
        guard value.range(of: pattern, options: .regularExpression) != nil else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        return formatter.date(from: value)
    }

    private static func buildLabel(start: Date, end: Date, cycleStartDay: Int) -> String {
        if cycleStartDay == 1 {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: start)
        }
        // Use en dash (–, U+2013), NOT hyphen-minus.
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "\(formatter.string(from: start)) – \(formatter.string(from: end))"
    }
}
