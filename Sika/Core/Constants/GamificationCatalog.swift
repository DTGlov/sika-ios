import SwiftUI

/// Shared catalog of visual / labeling constants for the gamification
/// surfaces (/badges, /streaks, /momentum, /health detail).
///
/// This file is a complement to `Sika/Core/Models/Health.swift`, where the
/// Phase 9 type definitions live (`BadgeCatalog`, `BadgeCatalogEntry`,
/// `MomentumTier` with `.threshold/.color/.iconName`, `MomentumEventType`
/// with `.points`, etc.). To avoid duplicate sources of truth, this file
/// only contains pieces that don't already exist in Health.swift:
///   - `RarityConfig` — gradient + glow per badge rarity (for BadgeCard chrome)
///   - `MomentumAmounts` — user-facing labels per event type (existing
///     `MomentumEventType.points` already covers the numeric side)
///   - `StreakMilestones` — milestone thresholds for /streaks
///
/// All values pinned to web's gamification constants. Adding / changing
/// any of these is a cross-platform coordinated release.

// MARK: - Rarity visual config (used by BadgeCardView)

struct RarityVisualConfig {
    let frameColor: Color
    let frameGradient: RadialGradient
    let glowIntensity: Double
}

enum RarityConfig {
    static func config(for rarity: BadgeRarity) -> RarityVisualConfig {
        switch rarity {
        case .common:
            return RarityVisualConfig(
                frameColor: Color(hex: 0x00D9A3),
                frameGradient: RadialGradient(
                    colors: [
                        Color(hex: 0x00D9A3).opacity(0.15),
                        Color(hex: 0x00D9A3).opacity(0)
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: 80
                ),
                glowIntensity: 0.20
            )
        case .rare:
            return RarityVisualConfig(
                frameColor: Color(hex: 0xD4AF37),
                frameGradient: RadialGradient(
                    colors: [
                        Color(hex: 0xD4AF37).opacity(0.25),
                        Color(hex: 0xD4AF37).opacity(0)
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: 80
                ),
                glowIntensity: 0.35
            )
        }
    }
}

// MARK: - Momentum event labels

/// User-facing labels for each `MomentumEventType`. Used by /momentum's
/// "How to Earn Points" list and the recent-events history. Insertion
/// order matches web's MOMENTUM_AMOUNTS array for the display list.
enum MomentumAmounts {
    static let entries: [(type: MomentumEventType, label: String)] = [
        (.transactionLogged,           "Logged a transaction"),
        (.transactionLoggedViaNudge,   "Logged via income nudge"),
        (.goalContribution,            "Contributed to a goal"),
        (.accountReconciled,           "Reconciled an account"),
        (.loggingStreak7Days,          "7-day logging streak"),
        (.goalCompleted,               "Completed a goal"),
        (.bucketWithinLimitFullMonth,  "All buckets within limit (full month)"),
    ]

    static func label(for type: MomentumEventType) -> String {
        entries.first { $0.type == type }?.label ?? type.rawValue
    }
}

// MARK: - Streak milestones

/// Thresholds at which streak surfaces celebrate the user.
/// Pinned to web — coordinated release if changed.
enum StreakMilestones {
    /// Logging streak milestones (days).
    static let logging: [Int] = [7, 14, 30, 60, 100]

    /// Savings streak milestones (weeks).
    static let savings: [Int] = [4, 12, 26, 52]

    /// Next logging milestone strictly greater than `current` (nil if maxed).
    static func nextLogging(after current: Int) -> Int? {
        logging.first { $0 > current }
    }

    /// Next savings milestone strictly greater than `current` (nil if maxed).
    static func nextSavings(after current: Int) -> Int? {
        savings.first { $0 > current }
    }
}
