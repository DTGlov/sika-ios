import SwiftUI

/// Ladder of all 5 tiers — icon + name + (optional) CURRENT pill +
/// threshold. Locked tiers (above current) fade their icon to 30%
/// opacity and use a muted name color.
struct AllTiersLadder: View {
    let totalPoints: Int

    private var currentTier: MomentumTier {
        MomentumProgressCalculator.calculateTier(totalPoints: totalPoints)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("All Tiers")
                .font(SikaTheme.Typography.sans(15, weight: .semibold))
                .foregroundStyle(SikaTheme.Color.foreground)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                ForEach(Array(MomentumTier.allCases.enumerated()), id: \.element) { index, tier in
                    tierRow(tier)
                    if index < MomentumTier.allCases.count - 1 {
                        Divider().background(SikaTheme.Color.mutedForeground.opacity(0.1))
                    }
                }
            }
            .padding(.vertical, 4)
            .background(SikaTheme.Color.card)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private func tierRow(_ tier: MomentumTier) -> some View {
        let isUnlocked = totalPoints >= tier.threshold
        let isCurrent = tier == currentTier

        return HStack(spacing: 12) {
            Image(systemName: tier.iconName)
                .font(.system(size: 18))
                .foregroundStyle(tier.color)
                .opacity(isUnlocked ? 1 : 0.3)
                .frame(width: 24)

            Text(tier.displayName)
                .font(SikaTheme.Typography.sans(14, weight: .semibold))
                .foregroundStyle(isUnlocked ? tier.color : SikaTheme.Color.mutedForeground)

            Spacer()

            if isCurrent {
                Text("CURRENT")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(tier.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(tier.color.opacity(0.13))
                    .clipShape(Capsule())
            }

            Text("\(tier.threshold.formatted()) pts")
                .font(SikaTheme.Typography.sans(13))
                .foregroundStyle(SikaTheme.Color.mutedForeground)
                .monospacedDigit()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
