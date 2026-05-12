import SwiftUI

/// Global overlay container for momentum-float bubbles. Reads
/// `AppState.pendingMomentumFloats` and renders one `MomentumFloatView` per
/// event, stacked vertically above the tab bar. Mounted as an overlay on
/// `AuthenticatedRootView` so any surface that calls
/// `enqueueMomentumFloat(points:)` produces a bubble.
///
/// Does not block input — `allowsHitTesting(false)` lets taps pass through.
struct MomentumFloatContainer: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 8) {
            Spacer()
            ForEach(appState.pendingMomentumFloats) { event in
                MomentumFloatView(event: event) { id in
                    appState.dismissMomentumFloat(id: id)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 100)  // clear the tab bar + FAB
        .allowsHitTesting(false)
    }
}
