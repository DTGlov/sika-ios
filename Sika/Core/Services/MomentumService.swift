import Foundation
import Supabase

/// Awards momentum points for events; persists totals + tier.
/// Tier ladder is computed locally per MomentumTier.from(totalPoints:).
final class MomentumService {
    private var client: SupabaseClient { SupabaseManager.shared.client }

    struct AwardResult: Equatable {
        let momentum: Momentum
        let pointsAwarded: Int
        let previousTotal: Int
        let tierChanged: Bool
        let newTier: MomentumTier
        let previousTier: MomentumTier
    }

    /// Awards points for a momentum event.
    /// Best-effort: errors logged + return nil. Mirror of awardMomentum.
    @discardableResult
    func award(userId: UUID, event: MomentumEventType) async -> AwardResult? {
        do {
            let existing = try await fetchOrCreateMomentum(userId: userId)

            let previousTotal = existing.totalPoints
            let previousTier = MomentumTier.from(totalPoints: previousTotal)
            let newTotal = previousTotal + event.points
            let newTier = MomentumTier.from(totalPoints: newTotal)
            let tierChanged = newTier != previousTier

            struct UpsertRow: Encodable {
                let user_id: UUID
                let total_points: Int
                let tier: String
            }
            let response: PostgrestResponse<Momentum> = try await client
                .from("momentum")
                .upsert(
                    UpsertRow(
                        user_id: userId,
                        total_points: newTotal,
                        tier: newTier.rawValue
                    ),
                    onConflict: "user_id"
                )
                .select()
                .single()
                .execute()

            // Append-only event log (best-effort within the same call)
            struct EventRow: Encodable {
                let user_id: UUID
                let event_type: String
                let points: Int
            }
            try? await client
                .from("momentum_events")
                .insert(EventRow(
                    user_id: userId,
                    event_type: event.rawValue,
                    points: event.points
                ))
                .execute()

            return AwardResult(
                momentum: response.value,
                pointsAwarded: event.points,
                previousTotal: previousTotal,
                tierChanged: tierChanged,
                newTier: newTier,
                previousTier: previousTier
            )
        } catch {
            #if DEBUG
            print("⚠️ MomentumService.award failed: \(error)")
            #endif
            return nil
        }
    }

    /// Read-only fetch used by HealthService snapshot composition.
    /// Returns nil on any error or missing row.
    func fetchMomentumOrNil(userId: UUID) async -> Momentum? {
        do {
            let response: PostgrestResponse<[Momentum]> = try await client
                .from("momentum")
                .select()
                .eq("user_id", value: userId)
                .limit(1)
                .execute()
            return response.value.first
        } catch {
            #if DEBUG
            print("⚠️ MomentumService.fetchMomentumOrNil failed (continuing as nil): \(error)")
            #endif
            return nil
        }
    }

    private func fetchOrCreateMomentum(userId: UUID) async throws -> Momentum {
        let response: PostgrestResponse<[Momentum]> = try await client
            .from("momentum")
            .select()
            .eq("user_id", value: userId)
            .limit(1)
            .execute()
        if let existing = response.value.first {
            return existing
        }

        struct NewRow: Encodable {
            let user_id: UUID
            let total_points: Int
            let tier: String
        }
        let inserted: PostgrestResponse<Momentum> = try await client
            .from("momentum")
            .insert(NewRow(
                user_id: userId,
                total_points: 0,
                tier: MomentumTier.bronze.rawValue
            ))
            .select()
            .single()
            .execute()
        return inserted.value
    }
}
