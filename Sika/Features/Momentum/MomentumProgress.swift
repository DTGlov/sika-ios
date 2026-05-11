import SwiftUI

/// Computed view of where the user sits in the tier ladder.
/// Mirror of web's `getTierProgress` in `lib/momentum.ts`.
struct TierProgress: Equatable {
    let currentTier: MomentumTier
    /// `nil` when the user is at the top of the ladder (Diamond).
    let nextTier: MomentumTier?
    /// 0.0 – 1.0, clamped.
    let progressPercent: Double
    /// Points accumulated since entering the current tier.
    let pointsInTier: Int
    /// Points still needed to reach the next tier; `0` when maxed.
    let pointsNeeded: Int
}

enum MomentumProgressCalculator {
    /// Resolve the tier whose threshold the user has crossed.
    /// Iterates in reverse so the highest matched threshold wins.
    static func calculateTier(totalPoints: Int) -> MomentumTier {
        for tier in MomentumTier.allCases.reversed() where totalPoints >= tier.threshold {
            return tier
        }
        return .bronze
    }

    /// One step up the ladder; `nil` when already at Diamond.
    static func nextTier(after tier: MomentumTier) -> MomentumTier? {
        guard
            let idx = MomentumTier.allCases.firstIndex(of: tier),
            idx + 1 < MomentumTier.allCases.count
        else { return nil }
        return MomentumTier.allCases[idx + 1]
    }

    /// Full progress block: current, next, percent fill, and pts-to-go.
    static func progress(totalPoints: Int) -> TierProgress {
        let currentTier = calculateTier(totalPoints: totalPoints)

        guard let nextTierValue = nextTier(after: currentTier) else {
            // Maxed out (Diamond) — bar fully filled, no points needed.
            return TierProgress(
                currentTier: currentTier,
                nextTier: nil,
                progressPercent: 1.0,
                pointsInTier: 0,
                pointsNeeded: 0
            )
        }

        let pointsInTier = totalPoints - currentTier.threshold
        let tierRange = nextTierValue.threshold - currentTier.threshold
        let progressPercent = tierRange > 0
            ? min(1.0, max(0.0, Double(pointsInTier) / Double(tierRange)))
            : 1.0
        let pointsNeeded = nextTierValue.threshold - totalPoints

        return TierProgress(
            currentTier: currentTier,
            nextTier: nextTierValue,
            progressPercent: progressPercent,
            pointsInTier: pointsInTier,
            pointsNeeded: pointsNeeded
        )
    }
}

// MARK: - MomentumTier glow

extension MomentumTier {
    /// Soft drop-shadow color for tier hero cards. Bronze/silver get a
    /// gentle 30% glow; gold steps up; platinum/diamond shine brighter.
    var glowColor: Color {
        switch self {
        case .bronze:   return color.opacity(0.30)
        case .silver:   return color.opacity(0.30)
        case .gold:     return color.opacity(0.35)
        case .platinum: return color.opacity(0.40)
        case .diamond:  return color.opacity(0.40)
        }
    }
}
