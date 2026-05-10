import Foundation
import Supabase

final class GoalService {
    private var client: SupabaseClient { SupabaseManager.shared.client }

    /// Fetch all goals for the authenticated user, ordered by priority asc.
    /// Used by Phase 2's Home GoalsWidget. Filters archived rows out.
    func fetchAll() async throws -> [Goal] {
        let response: PostgrestResponse<[Goal]> = try await client
            .from("goals")
            .select()
            .eq("is_archived", value: false)
            .order("priority", ascending: true)
            .order("created_at", ascending: true)
            .execute()
        return response.value
    }

    // MARK: - Phase Goals T1 — full CRUD + contribute + cycle

    /// Fetch all non-archived goals for a user, with stable ordering.
    /// Mirror of fetchGoals (lib/goals.ts).
    func fetchAll(userId: UUID) async throws -> [Goal] {
        let response: PostgrestResponse<[Goal]> = try await client
            .from("goals")
            .select()
            .eq("user_id", value: userId)
            .eq("is_archived", value: false)
            .order("priority", ascending: true)
            .order("created_at", ascending: true)
            .execute()
        return response.value
    }

    /// Fetch a single goal by id (RLS-scoped).
    func fetchOne(id: UUID) async throws -> Goal {
        let response: PostgrestResponse<Goal> = try await client
            .from("goals")
            .select()
            .eq("id", value: id)
            .single()
            .execute()
        return response.value
    }

    /// Net contributions − payments via two parallel queries on the
    /// transactions table. Mirror of fetchGoalAmounts.
    /// Returns (contributions, payments, net) all as Decimal.
    func fetchAmounts(goalId: UUID) async throws -> (contributions: Decimal, payments: Decimal, net: Decimal) {
        struct Row: Codable { let amount: Decimal }

        async let contribResponse: PostgrestResponse<[Row]> = client
            .from("transactions")
            .select("amount")
            .eq("goal_id", value: goalId)
            .eq("type", value: "transfer")
            .execute()

        async let paymentResponse: PostgrestResponse<[Row]> = client
            .from("transactions")
            .select("amount")
            .eq("paid_from_goal_id", value: goalId)
            .eq("type", value: "expense")
            .execute()

        let (cResp, pResp) = try await (contribResponse, paymentResponse)
        let contributions = cResp.value.reduce(Decimal(0)) { $0 + $1.amount }
        let payments = pResp.value.reduce(Decimal(0)) { $0 + $1.amount }
        return (contributions, payments, contributions - payments)
    }

    /// Full transaction rows for the detail page contributions list,
    /// newest first. Embeds the source + funding account names via the FK
    /// constraint shorthand pattern established in T1.
    func fetchContributions(goalId: UUID) async throws -> [TransactionListRow] {
        let response: PostgrestResponse<[TransactionListRow]> = try await client
            .from("transactions")
            .select(
                """
                *, \
                category:categories(*, bucket:budget_buckets(*)), \
                account:accounts!transactions_account_id_fkey(id,name,account_type,icon), \
                to_account:accounts!transactions_to_account_id_fkey(id,name,account_type,icon)
                """
            )
            .eq("goal_id", value: goalId)
            .eq("type", value: "transfer")
            .order("transaction_date", ascending: false)
            .execute()
        return response.value
    }

    /// Full transaction rows for the detail page payments list (read-only
    /// in T1; the paid_from_goal_id flow on transaction sheet is T2).
    func fetchPayments(goalId: UUID) async throws -> [TransactionListRow] {
        let response: PostgrestResponse<[TransactionListRow]> = try await client
            .from("transactions")
            .select(
                """
                *, \
                category:categories(*, bucket:budget_buckets(*)), \
                account:accounts!transactions_account_id_fkey(id,name,account_type,icon), \
                to_account:accounts!transactions_to_account_id_fkey(id,name,account_type,icon)
                """
            )
            .eq("paid_from_goal_id", value: goalId)
            .eq("type", value: "expense")
            .order("transaction_date", ascending: false)
            .execute()
        return response.value
    }

    /// Fetch the prior cycle's goal for the backlink on the detail page.
    func fetchPreviousCycle(previousGoalId: UUID) async throws -> Goal {
        try await fetchOne(id: previousGoalId)
    }

    /// Insert payload for create.
    struct CreatePayload: Encodable {
        let user_id: UUID
        let name: String
        let description: String?
        let goal_type: String
        let target_amount: Decimal?
        let deadline: String?
        let funding_account_id: UUID
        let priority: Int
        let icon: String?
        let color: String?
    }

    func create(payload: CreatePayload) async throws -> Goal {
        let response: PostgrestResponse<Goal> = try await client
            .from("goals")
            .insert(payload)
            .select()
            .single()
            .execute()
        return response.value
    }

    /// Update payload (same shape as create — no user_id mutation).
    struct UpdatePayload: Encodable {
        let name: String
        let description: String?
        let goal_type: String
        let target_amount: Decimal?
        let deadline: String?
        let funding_account_id: UUID
        let priority: Int
        let icon: String?
        let color: String?
    }

    func update(id: UUID, payload: UpdatePayload) async throws -> Goal {
        let response: PostgrestResponse<Goal> = try await client
            .from("goals")
            .update(payload)
            .eq("id", value: id)
            .select()
            .single()
            .execute()
        return response.value
    }

    /// Soft delete (archive). No restore UI on web; iOS matches.
    func archive(id: UUID) async throws {
        struct Row: Encodable { let is_archived: Bool }
        try await client
            .from("goals")
            .update(Row(is_archived: true))
            .eq("id", value: id)
            .execute()
    }

    /// Hard delete. Existing transactions remain; their `goal_id` /
    /// `paid_from_goal_id` FKs orphan or null per DB cascade rules.
    func delete(id: UUID) async throws {
        try await client
            .from("goals")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    /// Mark complete. Stamps `completed_at` to now (ISO8601).
    func markComplete(id: UUID) async throws {
        struct Row: Encodable { let completed_at: String }
        try await client
            .from("goals")
            .update(Row(completed_at: ISO8601DateFormatter().string(from: Date())))
            .eq("id", value: id)
            .execute()
    }

    /// Insert a contribution as a transfer transaction with `goal_id` set,
    /// then auto-complete the goal if its target was hit.
    /// Mirror of contributeToGoal.
    ///
    /// Convention (T1 fix): `account_id` = source (FROM), `to_account_id` =
    /// destination (TO). Goal contributions transfer FROM the user's
    /// `fromAccountId` TO the goal's funding account.
    @discardableResult
    func contribute(
        userId: UUID,
        goal: Goal,
        fromAccountId: UUID,
        amount: Decimal,
        note: String?,
        transactionDate: String,
        currentAmount: Decimal
    ) async throws -> Bool {
        struct InsertRow: Encodable {
            let user_id: UUID
            let account_id: UUID
            let to_account_id: UUID?
            let amount: Decimal
            let type: String
            let note: String?
            let transaction_date: String
            let goal_id: UUID
        }

        let resolvedNote: String = (note?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? note!
            : "Contribution to \(goal.name)")

        try await client
            .from("transactions")
            .insert(InsertRow(
                user_id: userId,
                account_id: fromAccountId,
                to_account_id: goal.fundingAccountId,
                amount: amount,
                type: "transfer",
                note: resolvedNote,
                transaction_date: transactionDate,
                goal_id: goal.id
            ))
            .execute()

        // Auto-complete: only for target goals that aren't already complete
        // and where this contribution pushes the running net at-or-above
        // target_amount.
        var autoCompleted = false
        if goal.goalType == .target,
           let target = goal.targetAmount,
           goal.completedAt == nil,
           currentAmount + amount >= target {
            try await markComplete(id: goal.id)
            autoCompleted = true
        }
        return autoCompleted
    }

    /// Create the next cycle goal. Carries forward icon/color/funding from
    /// the completed goal, sets `previous_goal_id` and bumps `cycle_count`.
    func createNextCycle(
        userId: UUID,
        completedGoal: Goal,
        name: String,
        targetAmount: Decimal,
        deadline: String,
        priority: Int
    ) async throws -> Goal {
        guard let fundingAccountId = completedGoal.fundingAccountId else {
            throw NSError(
                domain: "GoalService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Completed goal has no funding account."]
            )
        }
        struct InsertRow: Encodable {
            let user_id: UUID
            let name: String
            let description: String?
            let goal_type: String
            let target_amount: Decimal
            let deadline: String
            let funding_account_id: UUID
            let priority: Int
            let icon: String?
            let color: String?
            let previous_goal_id: UUID
            let cycle_count: Int
        }

        let response: PostgrestResponse<Goal> = try await client
            .from("goals")
            .insert(InsertRow(
                user_id: userId,
                name: name,
                description: completedGoal.description,
                goal_type: GoalType.target.rawValue,
                target_amount: targetAmount,
                deadline: deadline,
                funding_account_id: fundingAccountId,
                priority: priority,
                icon: completedGoal.icon,
                color: completedGoal.color,
                previous_goal_id: completedGoal.id,
                cycle_count: (completedGoal.cycleCount ?? 1) + 1
            ))
            .select()
            .single()
            .execute()
        return response.value
    }
}
