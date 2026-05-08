import Foundation
import Supabase

/// Backs Phase 4's hint system. RLS handles user-scoping on SELECT/DELETE,
/// so those methods don't take userId. The UPSERT path needs userId because
/// Supabase doesn't auto-fill `user_id` from auth.uid() on row insert.
final class DismissedHintService {
    private var client: SupabaseClient { SupabaseManager.shared.client }

    /// Fetches all dismissed hint ids for the current user.
    /// Returns raw strings (not HintIds) because the DB column is free-form
    /// text and we want to tolerate unknown values from older or future schemas.
    func fetchAll() async throws -> [String] {
        struct Row: Codable {
            let hint_id: String
        }
        let response: PostgrestResponse<[Row]> = try await client
            .from("dismissed_hints")
            .select("hint_id")
            .execute()
        return response.value.map { $0.hint_id }
    }

    /// Upserts a dismissal with composite-key conflict handling.
    /// userId is required on the row payload because Supabase doesn't
    /// auto-fill user_id from auth.uid() on insert.
    func dismiss(userId: UUID, hintId: HintId) async throws {
        struct Row: Encodable {
            let user_id: UUID
            let hint_id: String
        }
        try await client
            .from("dismissed_hints")
            .upsert(Row(user_id: userId, hint_id: hintId.rawValue),
                    onConflict: "user_id,hint_id")
            .execute()
    }

    /// Deletes all dismissed hints for the user. Used by Settings reset button
    /// (UI not shipped in this PR; AppState.resetHints() is wired for future use).
    func resetAll() async throws {
        try await client
            .from("dismissed_hints")
            .delete()
            .neq("hint_id", value: "")
            .execute()
    }
}
