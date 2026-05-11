import SwiftUI

/// /health detail page (Phase 9.5a).
///
/// NavigationStack push destination from `HealthRow`'s tap. Visualizes
/// the Phase 9 `HealthSnapshot`:
///   - score hero with 0→current count-up
///   - 4 stat tiles (logging streak, savings streak, momentum, badges)
///   - factor breakdown (5 cards, staggered entry, animated bars)
///   - Explore section (2×2 grid: Streaks / Momentum / Goals / Badges)
///   - how-this-works footer
///
/// Read-only. No mutations. Reuses the live `appState.healthSnapshot`
/// snapshot loaded by Phase 9's `HealthService`; never recomputes the
/// score locally.
///
/// Explore section (Phase 9.5a-explore fix-up):
///   - Streaks / Momentum / Badges tiles push placeholder destinations
///     within the current NavigationStack — 9.5b replaces with real
///     surfaces.
///   - Goals tile uses `onSwitchToTab(.goals)` (closure threaded from
///     `AuthenticatedRootView`) to cross-stack jump to the Goals tab.
///     Switching tabs unmounts the Home NavigationStack, so an explicit
///     `dismiss()` is unnecessary.
struct HealthDetailView: View {
    /// Cross-stack tab switcher. Threaded from `AuthenticatedRootView`
    /// through `AuthenticatedHomeView`. Used by the Explore section's
    /// Goals tile.
    let onSwitchToTab: (MainTab) -> Void

    @Environment(AppState.self) private var appState

    @State private var displayedScore: Int = 0
    @State private var factorsVisible: [Bool] = []
    @State private var hasAppeared: Bool = false

    // Explore section nav state (placeholder destinations within the
    // current /health stack).
    @State private var showStreaks: Bool = false
    @State private var showMomentum: Bool = false
    @State private var showBadges: Bool = false

    private var snapshot: HealthSnapshot? { appState.healthSnapshot }
    private var score: HealthScore? { snapshot?.score }
    private var factors: [HealthFactor] { score?.factors ?? [] }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                scoreHero
                statTilesRow
                factorsSection
                exploreSection
                tipsFooter
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(SikaTheme.Color.background)
        .navigationTitle("Your Sika score")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showStreaks) {
            StreakDetailPlaceholderView()
        }
        .navigationDestination(isPresented: $showMomentum) {
            MomentumDetailPlaceholderView()
        }
        .navigationDestination(isPresented: $showBadges) {
            BadgesGridPlaceholderView()
        }
        .onAppear {
            guard !hasAppeared else { return }
            hasAppeared = true
            factorsVisible = Array(repeating: false, count: factors.count)
            playEntranceAnimation()
        }
    }

    // MARK: - Score hero

    private var scoreHero: some View {
        VStack(spacing: 8) {
            Text("\(displayedScore)")
                .font(SikaTheme.Typography.sans(72, weight: .bold))
                .foregroundStyle(labelColor)
                .monospacedDigit()

            Text(labelText.uppercased())
                .font(SikaTheme.Typography.sans(13, weight: .semibold))
                .tracking(1.5)
                .foregroundStyle(labelColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(labelColor.opacity(0.12))
                .clipShape(Capsule())

            Text("Out of 100")
                .font(SikaTheme.Typography.sans(13))
                .foregroundStyle(SikaTheme.Color.mutedForeground)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(SikaTheme.Color.card)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(labelColor.opacity(0.25), lineWidth: 2)
        )
    }

    // MARK: - Stat tiles

    private var statTilesRow: some View {
        let loggingStreak = snapshot?.streaks?.loggingCurrent ?? 0
        let savingsStreak = snapshot?.streaks?.savingsCurrent ?? 0
        let momentumPoints = snapshot?.momentum?.totalPoints ?? 0
        let badges = snapshot?.userBadges.count ?? 0

        return HStack(spacing: 8) {
            StatTileCompact(
                label: "Streak",
                value: "\(loggingStreak)d",
                color: Color(hex: 0xF97316)
            )
            StatTileCompact(
                label: "Savings",
                value: "\(savingsStreak)w",
                color: Color(hex: 0x00D9A3)
            )
            StatTileCompact(
                label: "Momentum",
                value: "\(momentumPoints)",
                color: Color(hex: 0x60A5FA)
            )
            StatTileCompact(
                label: "Badges",
                value: "\(badges)/\(BadgeCatalog.totalCount)",
                color: Color(hex: 0xFBBF24)
            )
        }
    }

    // MARK: - Factors section

    private var factorsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Factor breakdown")
                .font(SikaTheme.Typography.sans(15, weight: .semibold))
                .foregroundStyle(SikaTheme.Color.foreground)
                .padding(.horizontal, 4)

            if factors.isEmpty {
                emptyFactors
            } else {
                ForEach(Array(factors.enumerated()), id: \.element.id) { index, factor in
                    FactorCardView(
                        factor: factor,
                        isVisible: factorsVisible.indices.contains(index)
                            ? factorsVisible[index]
                            : false
                    )
                }
            }
        }
    }

    private var emptyFactors: some View {
        Text("No factor breakdown available yet. Log a few transactions and check back.")
            .font(SikaTheme.Typography.sans(13))
            .foregroundStyle(SikaTheme.Color.mutedForeground)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(SikaTheme.Color.card)
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Explore section

    private var exploreSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Explore")
                .font(SikaTheme.Typography.sans(15, weight: .semibold))
                .foregroundStyle(SikaTheme.Color.foreground)
                .padding(.horizontal, 4)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8)
                ],
                spacing: 8
            ) {
                ExploreCardView(
                    iconName: "flame.fill",
                    iconColor: Color(hex: 0xF97316),
                    label: "Streaks",
                    onTap: { showStreaks = true }
                )
                ExploreCardView(
                    iconName: "rosette",
                    iconColor: Color(hex: 0xD4AF37),
                    label: "Momentum",
                    onTap: { showMomentum = true }
                )
                ExploreCardView(
                    iconName: "target",
                    iconColor: Color(hex: 0x00D9A3),
                    label: "Goals",
                    onTap: { onSwitchToTab(.goals) }
                )
                ExploreCardView(
                    iconName: "chart.line.uptrend.xyaxis",
                    iconColor: Color(hex: 0xA78BFA),
                    label: "Badges",
                    onTap: { showBadges = true }
                )
            }
        }
    }

    // MARK: - Tips footer

    private var tipsFooter: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("HOW THIS WORKS")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.5)
                .foregroundStyle(SikaTheme.Color.mutedForeground)
            Text("Your score updates as you log transactions, save toward goals, and stay within budget. Each factor is weighted to reflect long-term financial health, not just spending discipline.")
                .font(SikaTheme.Typography.sans(12))
                .foregroundStyle(SikaTheme.Color.mutedForeground)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SikaTheme.Color.muted.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Computed

    private var labelText: String {
        guard let label = score?.label else { return "—" }
        return label.displayName
    }

    private var labelColor: Color {
        guard let label = score?.label else { return SikaTheme.Color.mutedForeground }
        return label.color
    }

    // MARK: - Animation

    private func playEntranceAnimation() {
        let target = score?.total ?? 0
        // Count-up using a Timer-driven step. Linear-ish; ~1.2s total.
        animateScoreCountUp(to: target, totalDuration: 1.2)

        for index in factors.indices {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2 + Double(index) * 0.1) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    if factorsVisible.indices.contains(index) {
                        factorsVisible[index] = true
                    }
                }
            }
        }
    }

    /// Counts the displayed integer up from current → target. Splits
    /// the duration across `target` steps so the final tick lands on
    /// the right number. Cheap and deterministic.
    private func animateScoreCountUp(to target: Int, totalDuration: Double) {
        guard target > displayedScore else {
            displayedScore = target
            return
        }
        let remaining = target - displayedScore
        let stepInterval = max(0.01, totalDuration / Double(remaining))
        for step in 1...remaining {
            let nextValue = displayedScore + step
            DispatchQueue.main.asyncAfter(deadline: .now() + stepInterval * Double(step)) {
                displayedScore = nextValue
            }
        }
    }
}

// MARK: - Stat tile compact

private struct StatTileCompact: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.0)
                .foregroundStyle(SikaTheme.Color.mutedForeground)
            Text(value)
                .font(SikaTheme.Typography.sans(16, weight: .bold))
                .foregroundStyle(color)
                .monospacedDigit()
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(SikaTheme.Color.card)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
