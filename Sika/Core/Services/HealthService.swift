import Foundation

/// Composes the full health snapshot from streaks/momentum/badges + score compute.
/// Mirror of web's useProfile.ts parallel fetch + computeHealthScore call.
final class HealthService {
    private let scoreCalculator: HealthScoreCalculator
    private let streakService: StreakService
    private let momentumService: MomentumService
    private let badgeService: BadgeService

    init(
        scoreCalculator: HealthScoreCalculator = HealthScoreCalculator(),
        streakService: StreakService = StreakService(),
        momentumService: MomentumService = MomentumService(),
        badgeService: BadgeService = BadgeService()
    ) {
        self.scoreCalculator = scoreCalculator
        self.streakService = streakService
        self.momentumService = momentumService
        self.badgeService = badgeService
    }

    /// Loads the full health snapshot. Each piece degrades to nil/empty on
    /// fetch failure — never throws to the caller. Score computation is
    /// the only failable path; on its failure the snapshot still returns
    /// streaks/momentum/badges so HealthRow can render those fields.
    func fetchSnapshot(
        userId: UUID,
        categories: [TransactionCategory],
        budgetBuckets: [BudgetBucket]
    ) async -> HealthSnapshot {
        async let scoreResult: HealthScore? = (
            try? await scoreCalculator.computeHealthScore(
                userId: userId,
                categories: categories,
                budgetBuckets: budgetBuckets
            )
        )
        async let streaksResult = streakService.fetchStreaksOrNil(userId: userId)
        async let momentumResult = momentumService.fetchMomentumOrNil(userId: userId)
        async let badgesResult = badgeService.fetchUserBadges(userId: userId)

        let (score, streaks, momentum, badges) = await (
            scoreResult, streaksResult, momentumResult, badgesResult
        )

        return HealthSnapshot(
            score: score,
            streaks: streaks,
            momentum: momentum,
            userBadges: badges
        )
    }
}
