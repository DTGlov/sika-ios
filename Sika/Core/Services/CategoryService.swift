import Foundation
import Supabase

final class CategoryService {
    private var client: SupabaseClient { SupabaseManager.shared.client }

    /// Fetch all categories for the authenticated user.
    func fetchAll() async throws -> [TransactionCategory] {
        let response: PostgrestResponse<[TransactionCategory]> = try await client
            .from("categories")
            .select()
            .order("name", ascending: true)
            .execute()
        return response.value
    }

    /// Fetch only categories of a specific type (expense or income).
    func fetch(ofType type: CategoryType) async throws -> [TransactionCategory] {
        let response: PostgrestResponse<[TransactionCategory]> = try await client
            .from("categories")
            .select()
            .eq("category_type", value: type.rawValue)
            .order("name", ascending: true)
            .execute()
        return response.value
    }
}
