import Foundation
import Supabase

/// Backs Phase 5c's DailyDigest banner + /daily detail page.
/// Server-side cron writes one row per date in sika_daily_digests
/// (shared across all users, no user_id column). iOS reads + marks read.
final class SikaDailyService {
    private var client: SupabaseClient { SupabaseManager.shared.client }

    /// Fetches today's digest. Returns nil when no row for today
    /// (cron hasn't run yet, or skipped).
    /// Mirror of src/app/(app)/daily/page.tsx:73-82.
    func fetchTodayDigest() async throws -> DailyDigest? {
        let today = Self.todayString()
        let response: PostgrestResponse<[DailyDigest]> = try await client
            .from("sika_daily_digests")
            .select()
            .eq("digest_date", value: today)
            .limit(1)
            .execute()
        return response.value.first
    }

    /// Returns true if the user has already marked today's digest read.
    /// Mirror of the existing-read check at src/app/(app)/daily/page.tsx:87-99.
    /// RLS scopes to current user, but we explicitly filter by user_id for clarity.
    func hasReadToday(userId: UUID, digestDate: String) async throws -> Bool {
        struct Row: Codable {
            let user_id: UUID
        }
        let response: PostgrestResponse<[Row]> = try await client
            .from("user_daily_reads")
            .select("user_id")
            .eq("user_id", value: userId)
            .eq("digest_date", value: digestDate)
            .limit(1)
            .execute()
        return !response.value.isEmpty
    }

    /// Inserts a user_daily_reads row. Idempotent — duplicate inserts will
    /// fail the (user_id, digest_date) unique constraint, which we silently
    /// swallow.
    /// Mirror of markRead() in src/app/(app)/daily/page.tsx:111-120.
    func markRead(userId: UUID, digestDate: String) async {
        struct Payload: Encodable {
            let user_id: UUID
            let digest_date: String
        }
        do {
            try await client
                .from("user_daily_reads")
                .insert(Payload(user_id: userId, digest_date: digestDate))
                .execute()
        } catch {
            // 23505 unique violation = already marked, fine.
            // Other errors logged in DEBUG only — UI already showed optimistic update.
            #if DEBUG
            print("⚠️ markRead insert failed (likely already-read race): \(error)")
            #endif
        }
    }

    /// Returns today's date as YYYY-MM-DD using device-local timezone.
    /// Matches web's `new Date().toISOString().slice(0, 10)` close enough
    /// for the use case (digests are date-keyed; minor TZ skew at midnight
    /// is acceptable).
    private static func todayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        return formatter.string(from: Date())
    }
}
