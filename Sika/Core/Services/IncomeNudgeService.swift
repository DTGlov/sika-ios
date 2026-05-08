import Foundation
import Supabase

/// Backs Phase 7's IncomeNudgeCard. RLS scopes the dismissals query.
/// Pure derivation lives in `dueDateIfToday(source:today:)` (no DB).
final class IncomeNudgeService {
    private var client: SupabaseClient { SupabaseManager.shared.client }

    // MARK: - Pure derivation (matches web's src/lib/income-nudges.ts)

    /// Returns the due-date string if today matches this source's schedule, else nil.
    /// Mirror of web's getIncomeDueDate.
    static func dueDateIfToday(
        source: IncomeSource,
        today: Date = Date()
    ) -> String? {
        guard source.isActive, let expectedDay = source.expectedDay else { return nil }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        let todayStr = formatter.string(from: today)

        switch source.frequency {
        case .monthly:
            // Day-of-month match
            let day = calendar.component(.day, from: today)
            return (day == expectedDay) ? todayStr : nil

        case .weekly, .biweekly:
            // Day-of-week match. Apple's weekday is 1=Sun ... 7=Sat;
            // subtract 1 to align with web's 0=Sun ... 6=Sat convention.
            // Biweekly is approximated as weekly per web's comment.
            let weekday = calendar.component(.weekday, from: today) - 1
            return (weekday == expectedDay) ? todayStr : nil

        case .irregular:
            return nil
        }
    }

    // MARK: - Fetch + dismissal helpers

    /// Fetches all income nudges due today that haven't been dismissed.
    /// Mirror of web's getDueIncomeNudges.
    func dueNudges(
        userId: UUID,
        sources: [IncomeSource],
        today: Date = Date()
    ) async throws -> [IncomeNudge] {
        let dueSourcesWithDates: [(source: IncomeSource, dueDate: String)] =
            sources.compactMap { source in
                guard let dueDate = Self.dueDateIfToday(source: source, today: today) else {
                    return nil
                }
                return (source: source, dueDate: dueDate)
            }

        guard !dueSourcesWithDates.isEmpty else { return [] }

        let sourceIds = dueSourcesWithDates.map(\.source.id)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        let todayStr = formatter.string(from: today)

        struct DismissalRow: Codable {
            let income_source_id: UUID
        }

        let response: PostgrestResponse<[DismissalRow]> = try await client
            .from("income_nudge_dismissals")
            .select("income_source_id")
            .eq("user_id", value: userId)
            .eq("due_date", value: todayStr)
            .in("income_source_id", values: sourceIds)
            .execute()

        let dismissedIds = Set(response.value.map(\.income_source_id))

        return dueSourcesWithDates
            .filter { !dismissedIds.contains($0.source.id) }
            .map { IncomeNudge(incomeSource: $0.source, dueDate: $0.dueDate) }
    }

    /// Records a user response to an income nudge.
    /// Upserts on (user_id, income_source_id, due_date) composite key.
    /// Mirror of web's recordNudgeDismissal.
    func recordDismissal(
        userId: UUID,
        sourceId: UUID,
        dueDate: String,
        action: IncomeNudgeAction
    ) async throws {
        struct Row: Encodable {
            let user_id: UUID
            let income_source_id: UUID
            let due_date: String
            let action: String
        }
        try await client
            .from("income_nudge_dismissals")
            .upsert(
                Row(
                    user_id: userId,
                    income_source_id: sourceId,
                    due_date: dueDate,
                    action: action.rawValue
                ),
                onConflict: "user_id,income_source_id,due_date"
            )
            .execute()
    }
}
