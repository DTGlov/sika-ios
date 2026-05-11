import SwiftUI

/// /streaks destination — 3-card stat surface (Logging / Saving /
/// Freezes). Reads exclusively from `appState.healthSnapshot?.streaks`;
/// no direct DB query, no mutation hooks. Refreshes only on
/// navigate-away-and-back (when Home re-loads the snapshot).
///
/// Entry animation: three cards in a cascade. `.easeOut(0.3)` with
/// staggered delays of 0 / 0.08 / 0.16s — ~460ms total.
struct StreaksView: View {
    @Environment(AppState.self) private var appState

    @State private var card1Visible: Bool = false
    @State private var card2Visible: Bool = false
    @State private var card3Visible: Bool = false

    private var streaks: Streaks? {
        appState.healthSnapshot?.streaks
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                loggingCard
                    .opacity(card1Visible ? 1 : 0)
                    .offset(y: card1Visible ? 0 : 16)
                savingCard
                    .opacity(card2Visible ? 1 : 0)
                    .offset(y: card2Visible ? 0 : 16)
                freezesCard
                    .opacity(card3Visible ? 1 : 0)
                    .offset(y: card3Visible ? 0 : 16)
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .padding(.bottom, 32)
        }
        .background(SikaTheme.Color.background)
        .navigationTitle("Your Streaks")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            playStaggerAnimation()
        }
    }

    // MARK: - Cards

    private var loggingCard: some View {
        LoggingStreakCard(
            loggingCurrent: streaks?.loggingCurrent ?? 0,
            loggingLongest: streaks?.loggingLongest ?? 0,
            loggingLastDate: streaks?.loggingLastDate
        )
    }

    private var savingCard: some View {
        SavingStreakCard(
            savingsCurrent: streaks?.savingsCurrent ?? 0,
            savingsLongest: streaks?.savingsLongest ?? 0,
            savingsLastWeek: streaks?.savingsLastWeek
        )
    }

    private var freezesCard: some View {
        FreezesCard(
            freezesBanked: streaks?.freezesBanked ?? 0,
            freezesEarnedTotal: streaks?.freezesEarnedTotal ?? 0
        )
    }

    // MARK: - Animation

    private func playStaggerAnimation() {
        withAnimation(.easeOut(duration: 0.3)) {
            card1Visible = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.easeOut(duration: 0.3)) {
                card2Visible = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            withAnimation(.easeOut(duration: 0.3)) {
                card3Visible = true
            }
        }
    }
}
