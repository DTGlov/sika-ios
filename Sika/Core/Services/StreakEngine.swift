import Foundation

/// Pure date math for the streak engine. Mirror of web's src/lib/streaks.ts.
/// All functions are static + pure to enable unit testing without Supabase.
enum StreakEngine {

    static let loggingMilestones: [Int] = [7, 14, 30, 60, 100]
    static let savingsMilestones: [Int] = [4, 12, 26, 52]
    static let maxFreezes: Int = 2

    struct StreakUpdateResult: Equatable {
        let updatedStreaks: Streaks
        let milestoneHit: Int?
        let freezeUsed: Bool
        let freezeEarned: Bool
        let broken: Bool
    }

    // MARK: - Logging streak (daily)

    static func updateLoggingStreak(
        current streaks: Streaks,
        today: Date = Date()
    ) -> StreakUpdateResult {
        let todayStr = isoDateString(today)

        if streaks.loggingLastDate == todayStr {
            return StreakUpdateResult(
                updatedStreaks: streaks,
                milestoneHit: nil,
                freezeUsed: false,
                freezeEarned: false,
                broken: false
            )
        }

        var updated = streaks
        var newCurrent = streaks.loggingCurrent
        var newFreezesBanked = streaks.freezesBanked
        var freezeUsed = false
        var freezeEarned = false
        var broken = false

        if streaks.loggingLastDate == nil {
            newCurrent = 1
        } else if let last = streaks.loggingLastDate {
            let gap = daysBetween(from: last, to: todayStr)
            if gap == 1 {
                newCurrent += 1
            } else if gap > 1 {
                let freezesNeeded = gap - 1
                if streaks.freezesBanked >= freezesNeeded {
                    newFreezesBanked -= freezesNeeded
                    newCurrent += 1
                    freezeUsed = true
                } else {
                    newCurrent = 1
                    newFreezesBanked = 0
                    broken = true
                }
            }
            // gap <= 0 (clock skew or same-day caught above): no change
        }

        // Earn a freeze every 10 days, capped at maxFreezes
        if newCurrent > 0 && newCurrent.isMultiple(of: 10) && newFreezesBanked < maxFreezes {
            newFreezesBanked = min(maxFreezes, newFreezesBanked + 1)
            updated.freezesEarnedTotal += 1
            freezeEarned = true
        }

        let milestoneHit = loggingMilestones.first {
            newCurrent == $0 && !streaks.loggingMilestonesShown.contains($0)
        }

        updated.loggingCurrent = newCurrent
        updated.loggingLongest = max(updated.loggingLongest, newCurrent)
        updated.loggingLastDate = todayStr
        updated.freezesBanked = newFreezesBanked
        if let hit = milestoneHit {
            updated.loggingMilestonesShown.append(hit)
        }
        updated.updatedAt = Date()

        return StreakUpdateResult(
            updatedStreaks: updated,
            milestoneHit: milestoneHit,
            freezeUsed: freezeUsed,
            freezeEarned: freezeEarned,
            broken: broken
        )
    }

    // MARK: - Savings streak (weekly, Monday-anchored)

    static func updateSavingsStreak(
        current streaks: Streaks,
        today: Date = Date()
    ) -> StreakUpdateResult {
        let mondayStr = mondayOfWeek(for: today)

        if streaks.savingsLastWeek == mondayStr {
            return StreakUpdateResult(
                updatedStreaks: streaks,
                milestoneHit: nil,
                freezeUsed: false,
                freezeEarned: false,
                broken: false
            )
        }

        var updated = streaks
        var newCurrent = streaks.savingsCurrent
        var newFreezesBanked = streaks.freezesBanked
        var freezeUsed = false
        var broken = false

        if streaks.savingsLastWeek == nil {
            newCurrent = 1
        } else if let last = streaks.savingsLastWeek {
            let gap = weeksBetween(from: last, to: mondayStr)
            if gap == 1 {
                newCurrent += 1
            } else if gap > 1 {
                let freezesNeeded = gap - 1
                if streaks.freezesBanked >= freezesNeeded {
                    newFreezesBanked -= freezesNeeded
                    newCurrent += 1
                    freezeUsed = true
                } else {
                    newCurrent = 1
                    newFreezesBanked = 0
                    broken = true
                }
            }
        }

        let milestoneHit = savingsMilestones.first {
            newCurrent == $0 && !streaks.savingsMilestonesShown.contains($0)
        }

        updated.savingsCurrent = newCurrent
        updated.savingsLongest = max(updated.savingsLongest, newCurrent)
        updated.savingsLastWeek = mondayStr
        updated.freezesBanked = newFreezesBanked
        if let hit = milestoneHit {
            updated.savingsMilestonesShown.append(hit)
        }
        updated.updatedAt = Date()

        return StreakUpdateResult(
            updatedStreaks: updated,
            milestoneHit: milestoneHit,
            freezeUsed: freezeUsed,
            freezeEarned: false,
            broken: broken
        )
    }

    // MARK: - Helpers (used by HealthRow + tests)

    /// Predicate used by HealthRow's "should pulse" check.
    static func hasLoggedToday(_ streaks: Streaks?, today: Date = Date()) -> Bool {
        guard let last = streaks?.loggingLastDate else { return false }
        return last == isoDateString(today)
    }

    static func isoDateString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        return f.string(from: date)
    }

    /// ISO-week Monday (yyyy-MM-dd) for the given date in device-local time.
    static func mondayOfWeek(for date: Date) -> String {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .current
        let components = calendar.dateComponents(
            [.yearForWeekOfYear, .weekOfYear],
            from: date
        )
        let monday = calendar.date(from: components) ?? date
        return isoDateString(monday)
    }

    static func daysBetween(from: String, to: String) -> Int {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        guard let fromDate = f.date(from: from),
              let toDate = f.date(from: to) else { return 0 }
        let cal = Calendar.current
        let comps = cal.dateComponents([.day], from: fromDate, to: toDate)
        return comps.day ?? 0
    }

    static func weeksBetween(from: String, to: String) -> Int {
        daysBetween(from: from, to: to) / 7
    }
}
