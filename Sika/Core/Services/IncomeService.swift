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
