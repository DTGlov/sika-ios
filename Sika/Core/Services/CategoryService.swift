import Foundation
import Supabase

final class CategoryService {
    private var client: SupabaseClient { SupabaseManager.shared.client }

    /// Fetch all categories for the authenticated user.
    /// Includes archived rows — callers filter at the view boundary.
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

    // MARK: - Phase S3 — CRUD + archive/restore

    /// Insert / update payload for the Settings → Category form sheet.
    /// `archived` is included so the same struct serves both create
    /// (always false) and update (preserves current state).
    struct CategoryPayload: Encodable {
        let user_id: UUID
        let name: String
        let category_type: String
        let icon: String?
        let bucket_id: UUID?
        let archived: Bool
    }

    func create(payload: CategoryPayload) async throws -> TransactionCategory {
        let response: PostgrestResponse<TransactionCategory> = try await client
            .from("categories")
            .insert(payload)
            .select()
            .single()
            .execute()
        return response.value
    }

    func update(id: UUID, payload: CategoryPayload) async throws -> TransactionCategory {
        let response: PostgrestResponse<TransactionCategory> = try await client
            .from("categories")
            .update(payload)
            .eq("id", value: id)
            .select()
            .single()
            .execute()
        return response.value
    }

    /// Soft archive (`archived = true`). Transactions referencing this
    /// category remain — they keep displaying the row's name historically;
    /// the row just stops appearing in pickers (Transactions filter chips,
    /// Recurring form's category menu) and lands in Settings' Archived
    /// collapsible.
    ///
    /// Asymmetric to S2's income-source hard delete: categories must
    /// soft-archive because transactions reference them.
    func archive(id: UUID) async throws {
        struct Patch: Encodable { let archived: Bool }
        try await client
            .from("categories")
            .update(Patch(archived: true))
            .eq("id", value: id)
            .execute()
    }

    /// Restore from archive (`archived = false`).
    /// No confirmation needed at the view boundary — restore is reversible
    /// (the user can always archive again).
    func restore(id: UUID) async throws {
        struct Patch: Encodable { let archived: Bool }
        try await client
            .from("categories")
            .update(Patch(archived: false))
            .eq("id", value: id)
            .execute()
    }
}
