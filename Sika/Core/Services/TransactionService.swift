import Foundation
import Supabase

final class TransactionService {
    private var client: SupabaseClient { SupabaseManager.shared.client }

    /// Insert a single transaction; returns the persisted row (with server timestamps).
    func insert(_ draft: TransactionDraft) async throws -> Transaction {
        let response: PostgrestResponse<Transaction> = try await client
            .from("transactions")
            .insert(draft)
            .select()
            .single()
            .execute()
        return response.value
    }

    /// Fetch all active transactions for the current user, in date-descending order.
    /// Used by AppState bootstrap and pull-to-refresh.
    func fetchAll() async throws -> [Transaction] {
        let response: PostgrestResponse<[Transaction]> = try await client
            .from("transactions")
            .select()
            .eq("is_active", value: true)
            .order("transaction_date", ascending: false)
            .order("created_at", ascending: false)
            .execute()
        return response.value
    }
}
