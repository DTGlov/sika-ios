import Foundation
import Supabase

final class AccountService {
    private var client: SupabaseClient { SupabaseManager.shared.client }

    /// Fetch all accounts for the authenticated user.
    func fetchAll() async throws -> [Account] {
        let response: PostgrestResponse<[Account]> = try await client
            .from("accounts")
            .select()
            .order("created_at", ascending: true)
            .execute()
        return response.value
    }
}
