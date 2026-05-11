import Foundation

/// Decorated view model used by `BadgesView` + `BadgeCardView`.
/// Combines a catalog entry (`BadgeCatalog.entries`) with the user's
/// unlock state (a row in `user_badges`, surfaced via `UserBadge`).
struct BadgeWithUnlockStatus: Identifiable, Equatable {
    let id: String              // catalog key (e.g. "first_steps")
    let name: String
    let description: String
    let iconName: String
    let rarity: BadgeRarity
    let sortOrder: Int
    let unlocked: Bool
    let unlockedAt: Date?
}

extension BadgeWithUnlockStatus {
    /// Partition the full catalog into earned and locked buckets,
    /// each pre-sorted by catalog `sortOrder`.
    /// Locked badges keep their full description so users see the
    /// criteria (the criteria IS the tease — matches web behavior).
    static func partition(
        userBadges: [UserBadge]
    ) -> (earned: [BadgeWithUnlockStatus], locked: [BadgeWithUnlockStatus]) {
        let unlockedMap: [String: Date] = Dictionary(
            userBadges.map { ($0.badgeId, $0.unlockedAt) },
            uniquingKeysWith: { existing, _ in existing }
        )

        let all: [BadgeWithUnlockStatus] = BadgeCatalog.entries.map { entry in
            BadgeWithUnlockStatus(
                id: entry.id,
                name: entry.name,
                description: entry.description,
                iconName: entry.iconName,
                rarity: entry.rarity,
                sortOrder: entry.sortOrder,
                unlocked: unlockedMap[entry.id] != nil,
                unlockedAt: unlockedMap[entry.id]
            )
        }
        .sorted { $0.sortOrder < $1.sortOrder }

        return (
            earned: all.filter(\.unlocked),
            locked: all.filter { !$0.unlocked }
        )
    }
}
