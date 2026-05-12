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

    /// Fetch all transactions for the current user, in date-descending order.
    /// Used by AppState bootstrap and pull-to-refresh.
    func fetchAll() async throws -> [Transaction] {
        let response: PostgrestResponse<[Transaction]> = try await client
            .from("transactions")
            .select()
            .order("transaction_date", ascending: false)
            .order("created_at", ascending: false)
            .execute()
        return response.value
    }

    // MARK: - Phase T1 (transactions tab)

    /// Fetches a page of joined transaction rows for the Transactions tab.
    /// Returns rows + total count so the caller can drive "Load more".
    ///
    /// Server-side filters: period (date range), type, account
    /// (account_id OR to_account_id), category, amount range.
    /// Bucket filter is applied client-side by the caller — see audit doc.
    ///
    /// Mirror of web's loadTransactions (page.tsx).
    func fetchPage(
        userId: UUID,
        filters: TransactionFilters,
        cycleStartDay: Int,
        page: Int = 0,
        pageSize: Int = 50
    ) async throws -> (rows: [TransactionListRow], totalCount: Int) {
        let (orderColumn, ascending) = sortToColumn(filters.sort)

        // PostgREST embed disambiguation: when a table has multiple FKs to the
        // same target (here, transactions has account_id AND to_account_id
        // both pointing at accounts), the column-name shorthand doesn't
        // resolve and the schema-cache lookup fails (PGRST200). Reference
        // the FK constraints by name. Defaults follow Postgres naming.
        var query = client
            .from("transactions")
            .select(
                """
                *, \
                category:categories(*, bucket:budget_buckets(*)), \
                account:accounts!transactions_account_id_fkey(id,name,account_type,icon), \
                to_account:accounts!transactions_to_account_id_fkey(id,name,account_type,icon)
                """,
                head: false,
                count: .exact
            )
            .eq("user_id", value: userId)

        if let range = TransactionPeriodRange.dateRange(for: filters.period, cycleStartDay: cycleStartDay) {
            query = query
                .gte("transaction_date", value: range.from)
                .lte("transaction_date", value: range.to)
        }

        if let type = filters.type {
            query = query.eq("type", value: type.rawValue)
        }

        // Account filter covers both account_id (source) and to_account_id
        // (destination for transfers).
        if let accountId = filters.accountId {
            query = query.or("account_id.eq.\(accountId.uuidString),to_account_id.eq.\(accountId.uuidString)")
        }

        if let categoryId = filters.categoryId {
            query = query.eq("category_id", value: categoryId)
        }

        if let amountMin = filters.amountMin {
            query = query.gte("amount", value: NSDecimalNumber(decimal: amountMin).doubleValue)
        }
        if let amountMax = filters.amountMax {
            query = query.lte("amount", value: NSDecimalNumber(decimal: amountMax).doubleValue)
        }

        let response: PostgrestResponse<[TransactionListRow]> = try await query
            .order(orderColumn, ascending: ascending)
            .order("created_at", ascending: false)
            .range(from: page * pageSize, to: (page + 1) * pageSize - 1)
            .execute()

        return (response.value, response.count ?? 0)
    }

    /// Fetch ALL transactions for the user (no date filter, no pagination).
    /// Used by `AccountBalanceEngine` — minimal field set for performance.
    /// Matches web's pattern of pulling all rows on every balance refresh.
    func fetchAllForBalances(userId: UUID) async throws -> [Transaction] {
        let response: PostgrestResponse<[Transaction]> = try await client
            .from("transactions")
            .select()
            .eq("user_id", value: userId)
            .execute()
        return response.value
    }

    /// Hard delete. No soft-delete column on web; iOS mirrors.
    func deleteTransaction(id: UUID) async throws {
        try await client
            .from("transactions")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    /// Update an existing transaction (T2 edit branch).
    /// Returns the persisted row. Does NOT fire mutation hooks — the caller
    /// is responsible for keeping the edit branch off the streak/momentum/
    /// badge re-tick path.
    func update(id: UUID, payload: TransactionUpdate) async throws -> Transaction {
        let response: PostgrestResponse<Transaction> = try await client
            .from("transactions")
            .update(payload)
            .eq("id", value: id)
            .select()
            .single()
            .execute()
        return response.value
    }

    // MARK: - Helpers

    private func sortToColumn(_ sort: TransactionFilters.SortKey) -> (column: String, ascending: Bool) {
        switch sort {
        case .dateDesc:   return ("transaction_date", false)
        case .dateAsc:    return ("transaction_date", true)
        case .amountDesc: return ("amount", false)
        case .amountAsc:  return ("amount", true)
        }
    }
}

// MARK: - Period date range

/// Date range derivation for the period filter.
/// - cycle / prev_cycle use cycle_start_day (NOT calendar months)
/// - last30 / last90 are sliding windows from today
/// - all returns nil
enum TransactionPeriodRange {
    static func dateRange(
        for period: TransactionFilters.Period,
        cycleStartDay: Int,
        today: Date = Date()
    ) -> (from: String, to: String)? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current

        switch period {
        case .all:
            return nil
        case .cycle:
            let cycle = CycleCalculator.cycle(forDate: today, cycleStartDay: cycleStartDay)
            return (f.string(from: cycle.start), f.string(from: cycle.end))
        case .prevCycle:
            let cycle = CycleCalculator.cycle(atOffset: -1, fromDate: today, cycleStartDay: cycleStartDay)
            return (f.string(from: cycle.start), f.string(from: cycle.end))
        case .last30:
            let from = Calendar.current.date(byAdding: .day, value: -30, to: today) ?? today
            return (f.string(from: from), f.string(from: today))
        case .last90:
            let from = Calendar.current.date(byAdding: .day, value: -90, to: today) ?? today
            return (f.string(from: from), f.string(from: today))
        }
    }
}
