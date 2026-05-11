import SwiftUI

/// Single horizontal pill on Home. Top row: "Your Sika score: N · Label".
/// Bottom row: streak chip · momentum tier · badge count (each conditional).
/// Trailing chevron. The row itself is presentational — the tap that
/// pushes `HealthDetailView` (Phase 9.5a) is owned by the parent's
/// `Button { ... } label: { HealthRow(...) }` wrapping on Home.
struct HealthRow: View {
    let snapshot: HealthSnapshot?
    let hasLoggedToday: Bool

    var body: some View {
        if let snapshot, let score = snapshot.score {
            content(snapshot: snapshot, score: score)
        } else {
            skeleton
        }
    }

    @ViewBuilder
    private func content(snapshot: HealthSnapshot, score: HealthScore) -> some View {
        HStack(alignment: .center, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                topRow(score: score)
                bottomRow(snapshot: snapshot)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(SikaTheme.Color.mutedForeground.opacity(0.7))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .frame(minHeight: 62)
        .background(SikaTheme.Color.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(SikaTheme.Color.mutedForeground.opacity(0.2), lineWidth: 1)
        )
    }

    private func topRow(score: HealthScore) -> some View {
        HStack(spacing: 6) {
            Text("Your Sika score:")
                .font(SikaTheme.Typography.sans(14))
                .foregroundStyle(SikaTheme.Color.mutedForeground)
            Text("\(score.total)")
                .font(SikaTheme.Typography.sans(14, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(SikaTheme.Color.foreground)
            Text("·")
                .font(SikaTheme.Typography.sans(14))
                .foregroundStyle(SikaTheme.Color.mutedForeground.opacity(0.6))
            Text(score.label.displayName)
                .font(SikaTheme.Typography.sans(14, weight: .semibold))
                .foregroundStyle(score.label.color)
        }
    }

    @ViewBuilder
    private func bottomRow(snapshot: HealthSnapshot) -> some View {
        let loggingStreak = snapshot.streaks?.loggingCurrent ?? 0
        let tier = snapshot.momentum?.resolvedTier
        let badgeCount = snapshot.userBadges.count

        if loggingStreak > 0 || tier != nil || badgeCount > 0 {
            HStack(spacing: 6) {
                if loggingStreak > 0 {
                    streakChip(days: loggingStreak)
                }
                if tier != nil && loggingStreak > 0 {
                    bullet
                }
                if let tier {
                    tierChip(tier: tier)
                }
                if badgeCount > 0 && (tier != nil || loggingStreak > 0) {
                    bullet
                }
                if badgeCount > 0 {
                    Text("\(badgeCount)/\(BadgeCatalog.totalCount) badges")
                        .font(SikaTheme.Typography.sans(11))
                        .foregroundStyle(SikaTheme.Color.mutedForeground)
                }
            }
        }
    }

    private var bullet: some View {
        Text("·")
            .font(SikaTheme.Typography.sans(11))
            .foregroundStyle(SikaTheme.Color.mutedForeground.opacity(0.6))
    }

    private func streakChip(days: Int) -> some View {
        HStack(spacing: 3) {
            Image(systemName: "flame.fill")
                .font(.system(size: 11))
                .foregroundStyle(Color(hex: 0xF97316))
                .scaleEffect(shouldPulse ? 1.08 : 1.0)
                .animation(
                    shouldPulse
                        ? .easeInOut(duration: 1.5).repeatForever(autoreverses: true)
                        : .default,
                    value: shouldPulse
                )
            Text("\(days)d")
                .font(SikaTheme.Typography.sans(11))
                .monospacedDigit()
                .foregroundStyle(SikaTheme.Color.mutedForeground)
        }
    }

    private func tierChip(tier: MomentumTier) -> some View {
        HStack(spacing: 3) {
            Image(systemName: tier.iconName)
                .font(.system(size: 11))
                .foregroundStyle(tier.color)
            Text(tier.displayName)
                .font(SikaTheme.Typography.sans(11))
                .foregroundStyle(SikaTheme.Color.mutedForeground)
        }
    }

    private var shouldPulse: Bool {
        (snapshot?.streaks?.loggingCurrent ?? 0) > 0 && !hasLoggedToday
    }

    private var skeleton: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(SikaTheme.Color.muted)
            .frame(height: 62)
    }
}
