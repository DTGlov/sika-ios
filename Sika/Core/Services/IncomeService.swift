import Foundation
import Supabase

final class IncomeService {
    private var client: SupabaseClient { SupabaseManager.shared.client }

    /// Fetch all income sources for the authenticated user.
    func fetchAll() async throws -> [IncomeSource] {
        let response: PostgrestResponse<[IncomeSource]> = try await client
            .from("income_sources")
            .select()
            .order("created_at", ascending: true)
            .execute()
        return response.value
    }

    /// Insert multiple income sources in one batch.
    /// Returns the inserted rows with server-generated id/timestamps populated.
    func insertMany(_ drafts: [IncomeSourceDraft]) async throws -> [IncomeSource] {
        let response: PostgrestResponse<[IncomeSource]> = try await client
            .from("income_sources")
            .insert(drafts)
            .select()
            .execute()
        return response.value
    }

    // MARK: - Phase S2 — CRUD + syncMonthlyIncome

    /// Insert payload for the Settings → Income Sources form sheet.
    /// Mirror of the web `IncomeSourceInsert` shape; supports the full
    /// edit surface (icon + account_id) which the onboarding `IncomeSourceDraft`
    /// omits.
    struct IncomeSourcePayload: Encodable {
        let user_id: UUID
        let name: String
        let amount: Decimal
        let frequency: String
        let expected_day: Int?
        let icon: String?
        let account_id: UUID?
        let is_active: Bool
    }

    func create(payload: IncomeSourcePayload) async throws -> IncomeSource {
        let response: PostgrestResponse<IncomeSource> = try await client
            .from("income_sources")
            .insert(payload)
            .select()
            .single()
            .execute()
        return response.value
    }

    func update(id: UUID, payload: IncomeSourcePayload) async throws -> IncomeSource {
        let response: PostgrestResponse<IncomeSource> = try await client
            .from("income_sources")
            .update(payload)
            .eq("id", value: id)
            .select()
            .single()
            .execute()
        return response.value
    }

    /// Hard delete. Matches web exactly. (iOS adds a confirmation Alert
    /// at the view boundary; the network call is a one-shot delete.)
    func delete(id: UUID) async throws {
        try await client
            .from("income_sources")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    /// Compute and persist the aggregate monthly income to
    /// `profiles.monthly_income`. MUST run after every CRUD mutation.
    /// Phase 9's HealthRow reads `profile.monthlyIncome` — keeping this
    /// in sync is mandatory.
    ///
    /// Mirror of web's `syncMonthlyIncome` in src/lib/income.ts.
    func syncMonthlyIncome(userId: UUID, sources: [IncomeSource]) async throws {
        let total = sources
            .filter(\.isActive)
            .reduce(Decimal(0)) { $0 + IncomeService.monthlyEquivalent(amount: $1.amount, frequency: $1.frequency) }

        struct Patch: Encodable { let monthly_income: Decimal }
        try await client
            .from("profiles")
            .update(Patch(monthly_income: total))
            .eq("id", value: userId)
            .execute()
    }

    /// Monthly equivalent. Exact constants pinned to web's lib/income.ts:
    /// - monthly:   amount
    /// - weekly:    amount * 4.333
    /// - biweekly:  amount * 2.167
    /// - irregular: amount (treated as monthly for the aggregate)
    static func monthlyEquivalent(amount: Decimal, frequency: IncomeFrequency) -> Decimal {
        amount * frequency.monthlyMultiplier
    }
}

/// Insert payload — matches web's onboarding modal toInsert shape.
/// user_id is captured from the authenticated session by Supabase RLS;
/// the existing web code includes it explicitly, so we do too.
struct IncomeSourceDraft: Encodable {
    let userId: UUID
    let name: String
    let amount: Decimal
    let frequency: IncomeFrequency
    let expectedDay: Int?
    let isActive: Bool
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case name, amount, frequency
        case expectedDay = "expected_day"
        case isActive = "is_active"
        case notes
    }
}

/// Sum of monthlyEquivalent across all is_active sources.
/// Pure function so callers (onboarding view model, settings, etc.) share one definition.
func totalMonthlyIncome(_ sources: [IncomeSource]) -> Decimal {
    sources.filter(\.isActive).reduce(Decimal(0)) { $0 + $1.monthlyEquivalent }
}
