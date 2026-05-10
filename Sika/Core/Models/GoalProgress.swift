import Foundation

/// Computed progress snapshot for a goal. Pure value type — recomputed
/// per render from the goal + its derived currentAmount + funding account.
/// Mirror of web's GoalProgress.
struct GoalProgress: Equatable, Identifiable {
    let goal: Goal
    /// Net contributions − payments. Cached per render.
    let currentAmount: Decimal
    /// 0...100, target goals only. Nil for perpetual.
    let progressPercent: Double?
    /// Days from today to deadline (inclusive lower bound, clamped at 0).
    /// Nil for perpetual or unparseable deadline.
    let daysRemaining: Int?
    /// (target − currentAmount) / (daysRemaining / 30). Nil when not applicable.
    let requiredMonthlyPace: Decimal?
    let requiredWeeklyPace: Decimal?
    /// True when actual >= linear-pace expected by today. Nil for perpetual.
    let isOnTrack: Bool?
    /// Funding-account snapshot used by the card + detail header.
    let fundingAccount: JoinedAccountRef?

    var id: UUID { goal.id }
}
