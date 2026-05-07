import Foundation
import Supabase

final class BudgetBucketService {
    private var client: SupabaseClient { SupabaseManager.shared.client }

    /// Fetch all budget buckets for the authenticated user.
    /// Web's data model guarantees exactly 3 rows (needs/wants/savings) per user.
    func fetchAll() async throws -> [BudgetBucket] {
        let response: PostgrestResponse<[BudgetBucket]> = try await client
            .from("budget_buckets")
            .select()
            .order("sort_order", ascending: true)
            .execute()
        return response.value
    }
}
