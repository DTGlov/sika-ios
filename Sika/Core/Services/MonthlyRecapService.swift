import Foundation
import Supabase

/// Backs Phase 5b's MonthlyRecap banner + detail page.
/// Server-side cron writes one row per user per cycle-end; iOS reads + dismisses + marks viewed/shared.
final class MonthlyRecapService {
    private var client: SupabaseClient { SupabaseManager.shared.client }

    // MARK: - Fetch

    /// Fetches the latest monthly recap row for the user and applies the
    /// banner-trigger predicate client-side:
    ///   viewed_at IS NULL
    ///   AND dismissed_at IS NULL
    ///   AND generated_at >= now() - 30 days
    ///
    /// Volume is tiny (one row per user per cycle), so we fetch the latest
    /// few and filter in Swift instead of relying on the SDK's `.is()`
    /// null-filter (which has had portability issues).
    func fetchLatestForBanner() async throws -> MonthlyRecap? {
        let response: PostgrestResponse<[MonthlyRecap]> = try await client
            .from("monthly_recaps")
            .select()
            .order("month_start", ascending: false)
            .limit(5)
            .execute()

        let cutoff = Date().addingTimeInterval(-30 * 24 * 60 * 60)

        return response.value.first(where: { row in
            row.viewedAt == nil
                && row.dismissedAt == nil
                && row.generatedAt >= cutoff
        })
    }

    /// Fetches the latest recap regardless of state (used by detail when
    /// navigating from the banner — though Phase 5b pushes with the recap
    /// already in hand, this is exposed for future deep-link entry points).
    func fetchLatest() async throws -> MonthlyRecap? {
        let response: PostgrestResponse<[MonthlyRecap]> = try await client
            .from("monthly_recaps")
            .select()
            .order("month_start", ascending: false)
            .limit(1)
            .execute()
        return response.value.first
    }

    // MARK: - Mutations (direct Supabase UPDATEs)

    /// Marks the recap as viewed. Hides banner forever for this row.
    /// Idempotent — safe to call multiple times.
    func markViewed(recapId: UUID) async throws {
        let now = ISO8601DateFormatter().string(from: Date())
        struct Payload: Encodable { let viewed_at: String }
        try await client
            .from("monthly_recaps")
            .update(Payload(viewed_at: now))
            .eq("id", value: recapId)
            .execute()
    }

    /// Marks the recap as shared (analytics-only; doesn't affect banner visibility).
    func markShared(recapId: UUID) async throws {
        let now = ISO8601DateFormatter().string(from: Date())
        struct Payload: Encodable { let shared_at: String }
        try await client
            .from("monthly_recaps")
            .update(Payload(shared_at: now))
            .eq("id", value: recapId)
            .execute()
    }

    /// Dismisses the banner by setting dismissed_at.
    /// Note: web's MonthlyRecap TS type does not include dismissed_at;
    /// if the column doesn't exist on the table, this UPDATE will silently
    /// fail. The optimistic local clear in AppState still produces correct
    /// session behavior either way.
    func dismiss(recapId: UUID) async throws {
        let now = ISO8601DateFormatter().string(from: Date())
        struct Payload: Encodable { let dismissed_at: String }
        try await client
            .from("monthly_recaps")
            .update(Payload(dismissed_at: now))
            .eq("id", value: recapId)
            .execute()
    }
}
