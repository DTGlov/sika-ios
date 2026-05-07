import Foundation
import Supabase

final class GoalService {
    private var client: SupabaseClient { SupabaseManager.shared.client }

    /// Fetch all goals for the authenticated user, ordered by priority ascending
    /// (lower number = higher priority for Home's top-3 widget).
    func fetchAll() async throws -> [Goal] {
        let response: PostgrestResponse<[Goal]> = try await client
            .from("goals")
            .select()
            .order("priority", ascending: true)
            .execute()
        return response.value
    }
}
