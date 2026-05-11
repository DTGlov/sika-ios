import SwiftUI

/// Hero card at the top of /momentum: tier icon, eyebrow, name,
/// total points, and (conditionally) a progress bar to the next tier.
///
/// Animations:
///   - TierIcon: scale 0.8 → 1, opacity 0 → 1 on appear with a
///     `.spring(response: 0.4, dampingFraction: 0.55)` — approximates
///     web's Framer Motion `stiffness: 200, damping: 20`.
///   - Progress fill: 800ms `.easeOut`, 200ms delay after appear.
struct TierHeroCard: View {
    let totalPoints: Int

    @State private var tierIconVisible: Bool = false
    @State private var progressFillVisible: Bool = false

    private var progress: TierProgress {
        MomentumProgressCalculator.progress(totalPoints: totalPoints)
    }
    private var currentTier: MomentumTier { progress.currentTier }

    var body: some View {
        VStack(spacing: 16) {
            tierIcon
            eyebrow
            tierName
            totalLine
            if let nextTier = progress.nextTier {
                progressBlock(nextTier: nextTier)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .background(gradientBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(currentTier.color.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: currentTier.glowColor, radius: 20)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.55)) {
                tierIconVisible = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.easeOut(duration: 0.8)) {
                    progressFillVisible = true
                }
            }
        }
    }

    // MARK: - Hero pieces

    private var tierIcon: some View {
        Image(systemName: currentTier.iconName)
            .font(.system(size: 56, weight: .medium))
            .foregroundStyle(currentTier.color)
            .scaleEffect(tierIconVisible ? 1 : 0.8)
            .opacity(tierIconVisible ? 1 : 0)
    }

    private var eyebrow: some View {
        Text("CURRENT TIER")
            .font(.system(size: 11, weight: .semibold))
            .tracking(1.8)
            .foregroundStyle(currentTier.color)
    }

    private var tierName: some View {
        Text(currentTier.displayName)
            .font(SikaTheme.Typography.sans(28, weight: .bold))
            .foregroundStyle(SikaTheme.Color.foreground)
    }

    private var totalLine: some View {
        Text("\(totalPoints.formatted()) total points")
            .font(SikaTheme.Typography.sans(14))
            .foregroundStyle(SikaTheme.Color.mutedForeground)
            .monospacedDigit()
    }

    // MARK: - Progress to next tier (hidden when at Diamond)

    private func progressBlock(nextTier: MomentumTier) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text(currentTier.displayName)
                    .font(SikaTheme.Typography.sans(11))
                    .foregroundStyle(SikaTheme.Color.mutedForeground)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: nextTier.iconName)
                        .font(.system(size: 11))
                        .foregroundStyle(nextTier.color)
                    Text(nextTier.displayName)
                        .font(SikaTheme.Typography.sans(11))
                        .foregroundStyle(SikaTheme.Color.mutedForeground)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(SikaTheme.Color.muted.opacity(0.5))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(currentTier.color)
                        .frame(
                            width: progressFillVisible
                                ? max(0, geo.size.width * progress.progressPercent)
                                : 0,
                            height: 8
                        )
                }
            }
            .frame(height: 8)

            Text("\(progress.pointsNeeded.formatted()) pts to next tier")
                .font(SikaTheme.Typography.sans(12))
                .foregroundStyle(SikaTheme.Color.mutedForeground)
                .monospacedDigit()
        }
        .padding(.top, 8)
    }

    // MARK: - Background gradient (transparent → tier-tinted)

    private var gradientBackground: LinearGradient {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: SikaTheme.Color.background, location: 0),
                .init(color: currentTier.color.opacity(0.08), location: 1)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
