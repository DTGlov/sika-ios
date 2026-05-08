import Foundation
import Supabase

/// Backs Phase 6.5's CycleDetailView. Single Supabase fetch + in-memory
/// aggregation. Mirror of web's /dashboard/cycle-detail page (242 lines).
///
/// Note: web's query joins `categories` and `accounts` tables. iOS Transaction
/// model doesn't decode those nested objects, so we fetch transactions only
/// and look up category names via a `categoriesById` dict supplied by the
/// caller (AppState already holds `[TransactionCategory]`).
final class CycleDetailService {
    private var client: SupabaseClient { SupabaseManager.shared.client }

    /// Fetches all transactions in the cycle window and aggregates into a summary.
    /// `categoriesById` is the caller's lookup of TransactionCategory by id —
    /// AppState already holds this; pass it through to avoid a second query.
    func fetchSummary(
        cycle: Cycle,
        categoriesById: [UUID: TransactionCategory]
    ) async throws -> CycleDetailSummary {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current

        let cycleStartStr = formatter.string(from: cycle.start)
        let cycleEndStr = formatter.string(from: cycle.end)

        // RLS scopes to current user; no explicit user_id filter needed.
        let response: PostgrestResponse<[Transaction]> = try await client
            .from("transactions")
            .select()
            .gte("transaction_date", value: cycleStartStr)
            .lte("transaction_date", value: cycleEndStr)
            .order("transaction_date", ascending: false)
            .execute()

        return Self.aggregate(
            transactions: response.value,
            cycle: cycle,
            categoriesById: categoriesById
        )
    }

    /// Pure function — keep unit-testable.
    /// Mirror of web's buildBreakdown + breakdown derivation exactly.
    ///
    /// Income grouping: `category.name ?? note ?? "Other"` (3-tier fallback).
    /// Spending grouping: `category.name ?? "Uncategorized"` (2-tier; no note fallback).
    /// Spending excludes paid-from-goal transactions (sinking fund avoidance).
    /// Top spending capped at 5; income uncapped.
    static func aggregate(
        transactions txns: [Transaction],
        cycle: Cycle,
        categoriesById: [UUID: TransactionCategory]
    ) -> CycleDetailSummary {
        // Income: group by category name → note → "Other"
        let incomeMap = txns
            .filter { $0.type == .income }
            .reduce(into: [String: Decimal]()) { acc, t in
                let categoryName = t.categoryId.flatMap { categoriesById[$0]?.name }
                let key = categoryName ?? t.note ?? "Other"
                acc[key, default: 0] += t.amount
            }

        let receivedBySource = incomeMap
            .map { CycleBreakdownRow(name: $0.key, amount: $0.value) }
            .sorted { $0.amount > $1.amount }

        let totalReceived = receivedBySource.reduce(Decimal(0)) { $0 + $1.amount }

        // Spending: group by category name → "Uncategorized" (no note fallback).
        // Exclude paid-from-goal transactions to avoid double-counting savings spending.
        let spendingTxns = txns.filter { $0.type == .expense && $0.paidFromGoalId == nil }

        let spendingMap = spendingTxns
            .reduce(into: [String: Decimal]()) { acc, t in
                let categoryName = t.categoryId.flatMap { categoriesById[$0]?.name }
                let key = categoryName ?? "Uncategorized"
                acc[key, default: 0] += t.amount
            }

        let topSpending = Array(
            spendingMap
                .map { CycleBreakdownRow(name: $0.key, amount: $0.value) }
                .sorted { $0.amount > $1.amount }
                .prefix(5)
        )

        // totalSpent is computed from ALL spending (not just top 5).
        let totalSpent = spendingTxns.reduce(Decimal(0)) { $0 + $1.amount }

        return CycleDetailSummary(
            cycle: cycle,
            totalReceived: totalReceived,
            totalSpent: totalSpent,
            receivedBySource: receivedBySource,
            topSpending: topSpending
        )
    }
}
