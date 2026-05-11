import SwiftUI

/// Single badge tile in the /badges grid.
///
/// Chrome notes (audit Section 3):
///   - Medallion sized per `Size`; at `.md`, rare badges render at 80pt
///     vs 64pt for commons (rare are visibly larger to reward unlock)
///   - Earned: gradient fill + color frame + glow shadow + full-color icon
///   - Locked: muted fill + muted frame, grayscale icon at 60% opacity,
///     `lock.fill` overlay anchored bottom-right with a tiny halo
///   - Description shown for both unlocked AND locked (the criteria IS
///     the tease — matches web behavior)
struct BadgeCardView: View {
    enum Size {
        case sm, md, lg

        func medallionSize(for rarity: BadgeRarity) -> CGFloat {
            switch self {
            case .sm: return 48
            case .md: return rarity == .rare ? 80 : 64
            case .lg: return 112
            }
        }

        var iconSize: CGFloat {
            switch self {
            case .sm: return 20
            case .md: return 28
            case .lg: return 48
            }
        }
    }

    let badge: BadgeWithUnlockStatus
    let size: Size

    private var config: RarityVisualConfig { RarityConfig.config(for: badge.rarity) }
    private var medallionSize: CGFloat { size.medallionSize(for: badge.rarity) }

    var body: some View {
        VStack(spacing: 8) {
            medallion
            Text(badge.name)
                .font(SikaTheme.Typography.sans(12, weight: .semibold))
                .foregroundStyle(
                    badge.unlocked
                        ? SikaTheme.Color.foreground
                        : SikaTheme.Color.mutedForeground
                )
                .multilineTextAlignment(.center)
            Text(badge.description)
                .font(SikaTheme.Typography.sans(10))
                .foregroundStyle(SikaTheme.Color.mutedForeground.opacity(0.75))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 120)
        }
    }

    // MARK: - Medallion

    private var medallion: some View {
        ZStack {
            // Frame fill + stroke (rarity-tinted when unlocked, muted when locked)
            Circle()
                .fill(
                    badge.unlocked
                        ? AnyShapeStyle(config.frameGradient)
                        : AnyShapeStyle(SikaTheme.Color.muted)
                )
                .frame(width: medallionSize, height: medallionSize)
                .overlay(
                    Circle()
                        .stroke(
                            badge.unlocked
                                ? config.frameColor
                                : SikaTheme.Color.mutedForeground.opacity(0.3),
                            lineWidth: 2
                        )
                )
                .shadow(
                    color: badge.unlocked
                        ? config.frameColor.opacity(config.glowIntensity)
                        : .clear,
                    radius: 10
                )

            // Icon (full color when unlocked, grayscale + faded when locked)
            Image(systemName: badge.iconName)
                .font(.system(size: size.iconSize, weight: .medium))
                .foregroundStyle(
                    badge.unlocked
                        ? config.frameColor
                        : SikaTheme.Color.mutedForeground.opacity(0.4)
                )
                .opacity(badge.unlocked ? 1 : 0.6)
                .saturation(badge.unlocked ? 1 : 0)

            // Lock overlay (locked only) — anchored bottom-right of the medallion
            if !badge.unlocked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(SikaTheme.Color.mutedForeground)
                    .padding(4)
                    .background(SikaTheme.Color.background)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(SikaTheme.Color.mutedForeground.opacity(0.2), lineWidth: 0.5)
                    )
                    .offset(x: medallionSize / 2.6, y: medallionSize / 2.6)
            }
        }
        .frame(width: medallionSize, height: medallionSize)
    }
}
