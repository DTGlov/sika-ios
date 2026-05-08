import Foundation
import Supabase

/// Backs Phase 5a's DailyInsight banner. Server-side cron (00:30 UTC daily)
/// writes one row per user; iOS reads + dismisses the row.
final class DailyInsightService {
    private var client: SupabaseClient { SupabaseManager.shared.client }

    /// Fetches today's insight row for the given user.
    /// Returns nil when no row exists (cron hasn't run, or skipped for this user).
    /// Returns the row even if dismissed_at is set; the caller decides whether to display.
    func fetchToday(userId: UUID) async throws -> DailyInsightRow? {
        let today = Self.todayString()
        let response: PostgrestResponse<[DailyInsightRow]> = try await client
            .from("daily_insights")
            .select()
            .eq("user_id", value: userId)
            .eq("insight_date", value: today)
            .limit(1)
            .execute()
        return response.value.first
    }

    /// Marks today's insight as dismissed by setting dismissed_at to now.
    /// Per-day semantics: only affects today's row; tomorrow's cron generates
    /// a fresh un-dismissed row.
    ///
    /// The combination of user_id + insight_date eq filters identifies a
    /// unique row, so we don't add a `.is("dismissed_at", "null")` guard —
    /// overwriting an already-dismissed row's timestamp is harmless.
    func dismissToday(userId: UUID) async throws {
        let today = Self.todayString()
        let now = ISO8601DateFormatter().string(from: Date())

        struct DismissPayload: Encodable {
            let dismissed_at: String
        }

        try await client
            .from("daily_insights")
            .update(DismissPayload(dismissed_at: now))
            .eq("user_id", value: userId)
            .eq("insight_date", value: today)
            .execute()
    }

    /// Returns today's date as YYYY-MM-DD using the device's local timezone.
    /// If users in different timezones see different rows than expected,
    /// revisit by switching to UTC formatter (web uses UTC via toISOString).
    private static func todayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        return formatter.string(from: Date())
    }
}
