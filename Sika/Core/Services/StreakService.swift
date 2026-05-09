import Foundation
import Supabase

/// Supabase wrapper around StreakEngine. Reads + writes streaks rows.
/// Best-effort: failures are logged in DEBUG and swallowed otherwise.
final class StreakService {
    private var client: SupabaseClient { SupabaseManager.shared.client }

    /// Fetches existing streaks row or creates a fresh one.
    func fetchOrCreateStreaks(userId: UUID) async throws -> Streaks {
        let response: PostgrestResponse<[Streaks]> = try await client
            .from("streaks")
            .select()
            .eq("user_id", value: userId)
            .limit(1)
            .execute()

        if let existing = response.value.first {
            return existing
        }

        struct NewRow: Encodable {
            let user_id: UUID
            let logging_current: Int
            let logging_longest: Int
            let savings_current: Int
            let savings_longest: Int
            let freezes_banked: Int
            let freezes_earned_total: Int
            let logging_milestones_shown: [Int]
            let savings_milestones_shown: [Int]
        }
        let payload = NewRow(
            user_id: userId,
            logging_current: 0,
            logging_longest: 0,
            savings_current: 0,
            savings_longest: 0,
            freezes_banked: 0,
            freezes_earned_total: 0,
            logging_milestones_shown: [],
            savings_milestones_shown: []
        )
        let inserted: PostgrestResponse<Streaks> = try await client
            .from("streaks")
            .insert(payload)
            .select()
            .single()
            .execute()
        return inserted.value
    }

    /// Updates the logging streak. Mirror of updateLoggingStreak (streaks.ts).
    @discardableResult
    func updateLoggingStreak(userId: UUID) async -> StreakEngine.StreakUpdateResult? {
        do {
            let current = try await fetchOrCreateStreaks(userId: userId)
            let result = StreakEngine.updateLoggingStreak(current: current)
            try await persist(result.updatedStreaks)
            return result
        } catch {
            #if DEBUG
            print("⚠️ StreakService.updateLoggingStreak failed: \(error)")
            #endif
            return nil
        }
    }

    @discardableResult
    func updateSavingsStreak(userId: UUID) async -> StreakEngine.StreakUpdateResult? {
        do {
            let current = try await fetchOrCreateStreaks(userId: userId)
            let result = StreakEngine.updateSavingsStreak(current: current)
            try await persist(result.updatedStreaks)
            return result
        } catch {
            #if DEBUG
            print("⚠️ StreakService.updateSavingsStreak failed: \(error)")
            #endif
            return nil
        }
    }

    /// Read-only fetch used by HealthService snapshot composition.
    /// Returns nil on any error or missing row (new user).
    func fetchStreaksOrNil(userId: UUID) async -> Streaks? {
        do {
            let response: PostgrestResponse<[Streaks]> = try await client
                .from("streaks")
                .select()
                .eq("user_id", value: userId)
                .limit(1)
                .execute()
            return response.value.first
        } catch {
            #if DEBUG
            print("⚠️ StreakService.fetchStreaksOrNil failed (continuing as nil): \(error)")
            #endif
            return nil
        }
    }

    private func persist(_ streaks: Streaks) async throws {
        struct UpdateRow: Encodable {
            let logging_current: Int
            let logging_longest: Int
            let logging_last_date: String?
            let savings_current: Int
            let savings_longest: Int
            let savings_last_week: String?
            let freezes_banked: Int
            let freezes_earned_total: Int
            let logging_milestones_shown: [Int]
            let savings_milestones_shown: [Int]
        }
        let payload = UpdateRow(
            logging_current: streaks.loggingCurrent,
            logging_longest: streaks.loggingLongest,
            logging_last_date: streaks.loggingLastDate,
            savings_current: streaks.savingsCurrent,
            savings_longest: streaks.savingsLongest,
            savings_last_week: streaks.savingsLastWeek,
            freezes_banked: streaks.freezesBanked,
            freezes_earned_total: streaks.freezesEarnedTotal,
            logging_milestones_shown: streaks.loggingMilestonesShown,
            savings_milestones_shown: streaks.savingsMilestonesShown
        )
        try await client
            .from("streaks")
            .update(payload)
            .eq("user_id", value: streaks.userId)
            .execute()
    }
}
