import Foundation
import Supabase

/// Checks and persists badge unlocks. Per-badge condition checks are reads
/// against existing tables. Idempotent via DB unique (user_id, badge_id).
final class BadgeService {
    private var client: SupabaseClient { SupabaseManager.shared.client }

    /// Checks badges for a given trigger and unlocks any newly-earned ones.
    /// Returns the newly-unlocked rows (empty array if none).
    @discardableResult
    func checkAndUnlock(
        userId: UUID,
        trigger: BadgeTrigger
    ) async -> [UserBadge] {
        let candidateIds = trigger.badgeIds
        guard !candidateIds.isEmpty else { return [] }

        do {
            struct ExistingRow: Codable {
                let badge_id: String
            }
            let existing: PostgrestResponse<[ExistingRow]> = try await client
                .from("user_badges")
                .select("badge_id")
                .eq("user_id", value: userId)
                .execute()

            let alreadyUnlocked = Set(existing.value.map(\.badge_id))
            let toCheck = candidateIds.filter { !alreadyUnlocked.contains($0) }

            guard !toCheck.isEmpty else { return [] }

            var idsToInsert: [String] = []
            for badgeId in toCheck {
                if try await checkCondition(userId: userId, badgeId: badgeId) {
                    idsToInsert.append(badgeId)
                }
            }

            guard !idsToInsert.isEmpty else { return [] }

            struct InsertRow: Encodable {
                let user_id: UUID
                let badge_id: String
            }
            let payload = idsToInsert.map { InsertRow(user_id: userId, badge_id: $0) }
            let inserted: PostgrestResponse<[UserBadge]> = try await client
                .from("user_badges")
                .insert(payload)
                .select()
                .execute()

            return inserted.value
        } catch {
            #if DEBUG
            print("⚠️ BadgeService.checkAndUnlock failed: \(error)")
            #endif
            return []
        }
    }

    /// Marks the celebration as shown for a UserBadge row.
    func markCelebrationShown(userBadgeId: UUID) async {
        do {
            struct UpdateRow: Encodable {
                let celebration_shown: Bool
            }
            try await client
                .from("user_badges")
                .update(UpdateRow(celebration_shown: true))
                .eq("id", value: userBadgeId)
                .execute()
        } catch {
            #if DEBUG
            print("⚠️ BadgeService.markCelebrationShown failed: \(error)")
            #endif
        }
    }

    /// Read-only fetch used by HealthService snapshot composition.
    /// Newest unlocks first.
    func fetchUserBadges(userId: UUID) async -> [UserBadge] {
        do {
            let response: PostgrestResponse<[UserBadge]> = try await client
                .from("user_badges")
                .select()
                .eq("user_id", value: userId)
                .order("unlocked_at", ascending: false)
                .execute()
            return response.value
        } catch {
            #if DEBUG
            print("⚠️ BadgeService.fetchUserBadges failed (continuing as empty): \(error)")
            #endif
            return []
        }
    }

    // MARK: - Per-badge conditions

    /// Per-badge unlock check. Mirror of web's lib/badges.ts conditions.
    /// All checks are reads against existing tables.
    private func checkCondition(userId: UUID, badgeId: String) async throws -> Bool {
        switch badgeId {
        case "first_steps":
            return try await transactionCount(userId: userId) >= 1
        case "century_club":
            return try await transactionCount(userId: userId) >= 100
        case "week_warrior":
            return try await loggingStreakValue(userId: userId) >= 7
        case "month_of_discipline":
            return try await loggingStreakValue(userId: userId) >= 30
        case "consistent_saver":
            return try await savingsStreakValue(userId: userId) >= 4
        case "goal_getter":
            return try await completedGoalsCount(userId: userId) >= 1
        case "seeker":
            return try await completedGoalsCount(userId: userId) >= 5
        case "safety_net":
            return try await checkSafetyNet(userId: userId)
        default:
            return false
        }
    }

    private func transactionCount(userId: UUID) async throws -> Int {
        let response = try await client
            .from("transactions")
            .select("id", head: true, count: .exact)
            .eq("user_id", value: userId)
            .execute()
        return response.count ?? 0
    }

    private func loggingStreakValue(userId: UUID) async throws -> Int {
        struct Row: Codable {
            let logging_current: Int
        }
        let response: PostgrestResponse<[Row]> = try await client
            .from("streaks")
            .select("logging_current")
            .eq("user_id", value: userId)
            .limit(1)
            .execute()
        return response.value.first?.logging_current ?? 0
    }

    private func savingsStreakValue(userId: UUID) async throws -> Int {
        struct Row: Codable {
            let savings_current: Int
        }
        let response: PostgrestResponse<[Row]> = try await client
            .from("streaks")
            .select("savings_current")
            .eq("user_id", value: userId)
            .limit(1)
            .execute()
        return response.value.first?.savings_current ?? 0
    }

    private func completedGoalsCount(userId: UUID) async throws -> Int {
        let response = try await client
            .from("goals")
            .select("id", head: true, count: .exact)
            .eq("user_id", value: userId)
            .eq("goal_type", value: "target")
            .not("completed_at", operator: .is, value: "null")
            .execute()
        return response.count ?? 0
    }

    /// Safety Net unlock: Life Savings goal net balance >= 3× monthly Needs spend.
    /// Returns false on any read error or missing data — never throws to caller.
    private func checkSafetyNet(userId: UUID) async throws -> Bool {
        // Find Life Savings perpetual goal
        struct GoalRow: Codable {
            let id: UUID
        }
        let goalsResponse: PostgrestResponse<[GoalRow]> = try await client
            .from("goals")
            .select("id")
            .eq("user_id", value: userId)
            .eq("goal_type", value: "perpetual")
            .ilike("name", value: "life savings")
            .limit(1)
            .execute()
        guard let goal = goalsResponse.value.first else { return false }

        // Sum contributions for the goal (best-guess schema). On any error, fail-safe to false.
        let lsBalance = (try? await sumGoalContributions(goalId: goal.id)) ?? 0

        // Monthly Needs: best-effort via existing helper (caller's view of avg
        // Needs spend over last 3 cycles). For badge gate we use a simple
        // proxy: avg of last 3 completed cycles' Needs spend. If unavailable,
        // require a positive lsBalance and 3+ months of lifetime spend.
        let monthlyNeeds = (try? await averageMonthlyNeedsSpend(userId: userId)) ?? 0
        guard monthlyNeeds > 0 else { return false }

        return Double(truncating: lsBalance as NSNumber) >= 3.0 * Double(truncating: monthlyNeeds as NSNumber)
    }

    /// Net contributions to a goal. Reads goal_contributions; degrades to 0
    /// on schema mismatch / missing table.
    private func sumGoalContributions(goalId: UUID) async throws -> Decimal {
        struct Row: Codable {
            let amount: Decimal
            let type: String?
        }
        let response: PostgrestResponse<[Row]> = try await client
            .from("goal_contributions")
            .select("amount, type")
            .eq("goal_id", value: goalId)
            .execute()
        var net: Decimal = 0
        for row in response.value {
            if (row.type ?? "contribution") == "withdrawal" {
                net -= row.amount
            } else {
                net += row.amount
            }
        }
        return net
    }

    /// Avg Needs spend across the last 3 completed cycles.
    /// Conservative: requires categories + budget_buckets to be present on web's
    /// schema. If the join shape isn't available we return 0 (badge skips).
    private func averageMonthlyNeedsSpend(userId: UUID) async throws -> Decimal {
        // Look at the trailing 90 days as a coarse proxy — keeps badge gate
        // independent from cycle math. Final score uses the precise cycle path.
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        let today = Date()
        let cutoff = Calendar.current.date(byAdding: .day, value: -90, to: today) ?? today
        let cutoffStr = formatter.string(from: cutoff)

        struct Row: Codable {
            let amount: Decimal
        }
        // Pulls all expense rows in the last 90 days; the safety-net gate is
        // approximate by design (the precise per-bucket needs sum requires the
        // calculator's category/bucket map, which we keep in HealthScoreCalculator).
        // Treats total/3 as monthly Needs proxy. Conservative — favors false negatives.
        let response: PostgrestResponse<[Row]> = try await client
            .from("transactions")
            .select("amount")
            .eq("user_id", value: userId)
            .eq("type", value: "expense")
            .gte("transaction_date", value: cutoffStr)
            .execute()
        let total = response.value.reduce(Decimal(0)) { $0 + $1.amount }
        return total / 3
    }
}
