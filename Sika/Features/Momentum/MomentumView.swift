import SwiftUI
import Supabase

/// /momentum destination — tier hero + all-tiers ladder + how-to-earn
/// reference + recent activity history.
///
/// Reads the momentum singleton from `appState.healthSnapshot?.momentum`
/// and fetches up to 30 recent `momentum_events` on `.task`. The fetch
/// lives on this page rather than in `AppState.loadProfile` because
/// the events table grows unbounded — hot-pathing it on every app
/// launch is wasteful.
///
/// No skeleton state. If events are still loading (or fail), the
/// Recent Activity section simply doesn't render — matches web.
struct MomentumView: View {
    @Environment(AppState.self) private var appState

    @State private var events: [MomentumEvent] = []

    private var totalPoints: Int {
        appState.healthSnapshot?.momentum?.totalPoints ?? 0
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                TierHeroCard(totalPoints: totalPoints)
                AllTiersLadder(totalPoints: totalPoints)
                HowToEarnPoints()
                if !events.isEmpty {
                    RecentActivity(events: events)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 96)
        }
        .background(SikaTheme.Color.background)
        .navigationTitle("Momentum")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadEvents()
        }
    }

    private func loadEvents() async {
        guard let userId = appState.session?.user.id else { return }
        do {
            let fetched = try await MomentumService().fetchRecentEvents(userId: userId)
            events = fetched
        } catch {
            #if DEBUG
            print("⚠️ MomentumView.loadEvents failed: \(error)")
            #endif
        }
    }
}
