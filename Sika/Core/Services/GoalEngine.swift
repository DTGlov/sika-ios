import Foundation

/// Pure helpers for goal computations.
/// Mirror of web's lib/goals.ts: computeGoalProgress, suggestNextCycleName,
/// suggestNextDeadline.
enum GoalEngine {

    // MARK: - Progress

    /// Computes a `GoalProgress` snapshot for the given goal + current amount.
    /// All work is purely date math + ratios; no I/O.
    static func computeProgress(
        goal: Goal,
        currentAmount: Decimal,
        fundingAccount: JoinedAccountRef?,
        today: Date = Date()
    ) -> GoalProgress {
        let isPerpetual = goal.goalType == .perpetual

        var progressPercent: Double? = nil
        var daysRemaining: Int? = nil
        var requiredMonthlyPace: Decimal? = nil
        var requiredWeeklyPace: Decimal? = nil
        var isOnTrack: Bool? = nil

        if !isPerpetual,
           let target = goal.targetAmount,
           target > 0,
           let deadlineStr = goal.deadline,
           let deadline = parseDateOnly(deadlineStr) {

            let currentD = doubleFromDecimal(currentAmount)
            let targetD = doubleFromDecimal(target)
            let pct = (currentD / targetD) * 100.0
            progressPercent = min(100.0, max(0.0, pct))

            let calendar = Calendar.current
            let todayStart = calendar.startOfDay(for: today)
            let deadlineStart = calendar.startOfDay(for: deadline)
            let dr = max(0, calendar.dateComponents([.day], from: todayStart, to: deadlineStart).day ?? 0)
            daysRemaining = dr

            let remaining = max(Decimal(0), target - currentAmount)
            if dr > 0 {
                let drDecimal = Decimal(dr)
                requiredMonthlyPace = remaining / (drDecimal / Decimal(30))
                requiredWeeklyPace  = remaining / (drDecimal / Decimal(7))
            }

            // Pace status: linear expectation from createdAt → deadline.
            // Phase 9 lesson: createdAt is timestamptz on DB, decodes as Date.
            if let createdAt = goal.createdAt {
                let createdStart = calendar.startOfDay(for: createdAt)
                let totalDays = calendar.dateComponents([.day], from: createdStart, to: deadlineStart).day ?? 0
                if totalDays > 0 {
                    let elapsed = totalDays - dr
                    let expectedByNow = (Double(elapsed) / Double(totalDays)) * targetD
                    isOnTrack = currentD >= expectedByNow
                }
            }
        }

        return GoalProgress(
            goal: goal,
            currentAmount: currentAmount,
            progressPercent: progressPercent,
            daysRemaining: daysRemaining,
            requiredMonthlyPace: requiredMonthlyPace,
            requiredWeeklyPace: requiredWeeklyPace,
            isOnTrack: isOnTrack,
            fundingAccount: fundingAccount
        )
    }

    // MARK: - Cycle helpers

    /// Suggests the name for the next cycle of a target goal that just completed.
    /// Strips any trailing " 2025…" suffix from the source name and replaces it
    /// with " {nextYear} {H1|H2}" — H1 if completion was in Jul-Dec (next half
    /// is Jan-Jun of next year), else H2.
    /// Mirror of suggestNextCycleName.
    static func suggestNextCycleName(currentName: String, completionDate: Date) -> String {
        // Match base portion (everything before optional " 2025…" suffix).
        // Pattern: ^(.*?)(\s+\d{4}.*)?$
        let pattern = #"^(.*?)(\s+\d{4}.*)?$"#
        let base: String = {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: currentName, range: NSRange(currentName.startIndex..., in: currentName)),
                  match.numberOfRanges >= 2,
                  let r = Range(match.range(at: 1), in: currentName)
            else { return currentName }
            return String(currentName[r]).trimmingCharacters(in: .whitespaces)
        }()

        let calendar = Calendar.current
        let nextDate = calendar.date(byAdding: .month, value: 6, to: completionDate) ?? completionDate

        let yearFormatter = DateFormatter()
        yearFormatter.dateFormat = "yyyy"
        yearFormatter.locale = Locale(identifier: "en_US_POSIX")
        let nextYear = yearFormatter.string(from: nextDate)

        // completionDate's month — Calendar.month is 1-indexed; treat <= 6 as
        // first half (next cycle is H2), > 6 as second half (next cycle H1).
        let month = calendar.component(.month, from: completionDate)
        let half = month <= 6 ? "H2" : "H1"

        return "\(base) \(nextYear) \(half)"
    }

    /// Suggests the deadline for the next cycle: completion + 6 months,
    /// formatted YYYY-MM-DD.
    static func suggestNextDeadline(completionDate: Date) -> String {
        let calendar = Calendar.current
        let nextDate = calendar.date(byAdding: .month, value: 6, to: completionDate) ?? completionDate
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        return formatter.string(from: nextDate)
    }

    // MARK: - Helpers

    /// Parses a YYYY-MM-DD date-only string. Phase 9 lesson: Supabase `date`
    /// columns return strings without time component.
    static func parseDateOnly(_ str: String) -> Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        return f.date(from: str)
    }

    private static func doubleFromDecimal(_ d: Decimal) -> Double {
        Double(truncating: d as NSNumber)
    }
}
