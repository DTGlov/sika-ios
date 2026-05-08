import Foundation
import Supabase

/// Backs Phase 7's recurring auto-log + pending surfacing.
final class RecurringService {
    private var client: SupabaseClient { SupabaseManager.shared.client }

    /// Fetches active recurring rules with all their missed due dates.
    /// Mirror of web's getDueRecurring (recurring.ts).
    /// Caps at 365 occurrences per rule (safety guard against runaway loops).
    /// RLS scopes to current user; userId param kept for explicitness.
    func dueRecurring(today: Date = Date()) async throws -> [PendingRecurring] {
        let response: PostgrestResponse<[RecurringTransaction]> = try await client
            .from("recurring_transactions")
            .select()
            .eq("is_active", value: true)
            .eq("is_paused", value: false)
            .execute()
        let rules = response.value

        guard !rules.isEmpty else { return [] }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current

        let todayStartOfDay = calendar.startOfDay(for: today)

        var result: [PendingRecurring] = []

        for rule in rules {
            // Anchor: day after last_generated_date OR rule's start_date
            let fromDate: Date
            if let lastGenStr = rule.lastGeneratedDate,
               let lastGen = formatter.date(from: lastGenStr) {
                fromDate = calendar.date(byAdding: .day, value: 1, to: lastGen) ?? lastGen
            } else if let start = formatter.date(from: rule.startDate) {
                fromDate = start
            } else {
                continue  // unparseable; skip
            }

            var dueDates: [String] = []
            var cursor = fromDate

            while dueDates.count < 365 {  // safety cap
                guard let next = RecurringDateMath.nextDueDate(for: rule, from: cursor) else { break }

                let nextStartOfDay = calendar.startOfDay(for: next)
                if nextStartOfDay > todayStartOfDay { break }

                dueDates.append(formatter.string(from: next))
                cursor = calendar.date(byAdding: .day, value: 1, to: next) ?? next
            }

            if !dueDates.isEmpty {
                result.append(PendingRecurring(recurring: rule, dueDates: dueDates))
            }
        }

        return result
    }

    /// Fetches due recurring rules and silently materializes auto_log=true ones.
    /// Returns only auto_log=false rules as pending (for UI).
    /// Mirror of web's generateDueTransactions (recurring.ts).
    func generateAndCollectPending(userId: UUID, today: Date = Date()) async throws -> [PendingRecurring] {
        let due = try await dueRecurring(today: today)
        var pending: [PendingRecurring] = []

        for item in due {
            let rule = item.recurring

            if !rule.autoLog {
                pending.append(item)
                continue
            }

            // Auto-log: insert one transaction per missed occurrence
            for dueDate in item.dueDates {
                try await insertAutoLoggedTransaction(
                    rule: rule,
                    userId: userId,
                    transactionDate: dueDate
                )
            }

            // Bump last_generated_date to the latest
            if let latest = item.dueDates.last {
                try await updateLastGeneratedDate(recurringId: rule.id, date: latest)
            }
        }

        return pending
    }

    /// Confirms a pending recurring (insert one tx + bump last_generated_date).
    /// Mirror of web's confirmPendingRecurring.
    func confirmPending(userId: UUID, recurring: RecurringTransaction, dueDate: String) async throws {
        try await insertAutoLoggedTransaction(
            rule: recurring,
            userId: userId,
            transactionDate: dueDate
        )
        try await updateLastGeneratedDate(recurringId: recurring.id, date: dueDate)
    }

    /// Skips a pending recurring (just bump last_generated_date).
    func skipPending(recurringId: UUID, dueDate: String) async throws {
        try await updateLastGeneratedDate(recurringId: recurringId, date: dueDate)
    }

    // MARK: - Private helpers

    private func insertAutoLoggedTransaction(
        rule: RecurringTransaction,
        userId: UUID,
        transactionDate: String
    ) async throws {
        struct Row: Encodable {
            let user_id: UUID
            let account_id: UUID
            let category_id: UUID?
            let amount: Decimal
            let type: String
            let note: String?
            let transaction_date: String
            let generated_from_recurring: UUID
        }
        try await client
            .from("transactions")
            .insert(Row(
                user_id: userId,
                account_id: rule.accountId,
                category_id: rule.categoryId,
                amount: rule.amount,
                type: rule.type.rawValue,
                note: rule.note,
                transaction_date: transactionDate,
                generated_from_recurring: rule.id
            ))
            .execute()
    }

    private func updateLastGeneratedDate(recurringId: UUID, date: String) async throws {
        struct Row: Encodable {
            let last_generated_date: String
        }
        try await client
            .from("recurring_transactions")
            .update(Row(last_generated_date: date))
            .eq("id", value: recurringId)
            .execute()
    }
}
