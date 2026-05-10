import Foundation
import Supabase

final class AccountService {
    private var client: SupabaseClient { SupabaseManager.shared.client }

    /// Fetch all active accounts for the authenticated user, sorted by
    /// sort_order asc (creation order). Filters `is_active != false`.
    func fetchAll() async throws -> [Account] {
        let response: PostgrestResponse<[Account]> = try await client
            .from("accounts")
            .select()
            .eq("is_active", value: true)
            .order("sort_order", ascending: true)
            .order("created_at", ascending: true)
            .execute()
        return response.value
    }

    // MARK: - Phase Accounts T1 — CRUD + reconcile + balance helpers

    /// Pre-delete count of transactions referencing this account_id. Does NOT
    /// count to_account_id references (those would block on FK).
    func countTransactionsReferencingAccountId(_ accountId: UUID) async throws -> Int {
        let response = try await client
            .from("transactions")
            .select("id", head: true, count: .exact)
            .eq("account_id", value: accountId)
            .execute()
        return response.count ?? 0
    }

    /// Bulk-update transactions.account_id from one account to another.
    /// Used by delete-with-reassign flow.
    func reassignTransactions(from sourceId: UUID, to targetId: UUID) async throws {
        struct Row: Encodable { let account_id: UUID }
        try await client
            .from("transactions")
            .update(Row(account_id: targetId))
            .eq("account_id", value: sourceId)
            .execute()
    }

    /// Hard delete an account. Caller must reassign transactions first.
    /// FK errors on goals.funding_account_id, recurring_transactions.account_id,
    /// or transactions.to_account_id will surface as a thrown error.
    func delete(id: UUID) async throws {
        try await client
            .from("accounts")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    /// Two-step single-default enforcement step 1:
    /// flips all is_default=true rows for this user to is_default=false.
    /// Caller then inserts/updates the new default in step 2.
    func clearAllDefaults(userId: UUID) async throws {
        struct Row: Encodable { let is_default: Bool }
        try await client
            .from("accounts")
            .update(Row(is_default: false))
            .eq("user_id", value: userId)
            .eq("is_default", value: true)
            .execute()
    }

    struct AccountInsert: Encodable {
        let user_id: UUID
        let name: String
        let account_type: String
        let icon: String?            // dead-write
        let color: String?           // dead-write
        let opening_balance: Decimal
        let is_default: Bool
        let is_active: Bool
        let sort_order: Int
    }

    func create(payload: AccountInsert) async throws -> Account {
        let response: PostgrestResponse<Account> = try await client
            .from("accounts")
            .insert(payload)
            .select()
            .single()
            .execute()
        return response.value
    }

    struct AccountUpdate: Encodable {
        let name: String
        let account_type: String
        let icon: String?
        let color: String?
        let opening_balance: Decimal
        let is_default: Bool
        let is_active: Bool
    }

    func update(id: UUID, payload: AccountUpdate) async throws -> Account {
        let response: PostgrestResponse<Account> = try await client
            .from("accounts")
            .update(payload)
            .eq("id", value: id)
            .select()
            .single()
            .execute()
        return response.value
    }

    /// Insert an adjustment transaction for inline reconcile. Diff goes both
    /// ways: positive when actual > sika, negative otherwise.
    ///
    /// TODO (Phase 9.5b): wire `awardMomentum(.accountReconciled)` and
    /// `checkAndUnlockBadges(.accountReconciled)` here AND in the standalone
    /// reconcile sheet. Both reconcile paths should fire the same chain.
    func insertReconcileAdjustment(
        userId: UUID,
        accountId: UUID,
        sikaBalance: Decimal,
        actualBalance: Decimal
    ) async throws {
        let diff = actualBalance - sikaBalance
        let formattedActual = NSDecimalNumber(decimal: actualBalance)
            .description(withLocale: Locale(identifier: "en_US_POSIX"))

        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        let today = f.string(from: Date())

        struct Payload: Encodable {
            let user_id: UUID
            let amount: Decimal
            let type: String
            let category_id: UUID?       // null — adjustments don't bind to a category
            let account_id: UUID
            let to_account_id: UUID?     // null
            let note: String
            let transaction_date: String
        }
        try await client
            .from("transactions")
            .insert(Payload(
                user_id: userId,
                amount: diff,
                type: "adjustment",
                category_id: nil,
                account_id: accountId,
                to_account_id: nil,
                note: "Reconciled to \(formattedActual)",
                transaction_date: today
            ))
            .execute()
    }
}
