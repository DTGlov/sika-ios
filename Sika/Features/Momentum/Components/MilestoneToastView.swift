import SwiftUI

/// Global milestone-celebration toast. Rendered as an overlay on
/// `AuthenticatedRootView` whenever `AppState.pendingMilestoneToast` is set.
/// Fires AFTER the type-aware "Logged" toast with a 500ms delay, displays
/// for 3s, then self-dismisses via `AppState.dismissMilestoneToast()`.
///
/// Surface: anchored to the top of the screen, same family as `SikaToast`
/// but distinct so it can coexist with the wizard's "Logged" toast.
struct MilestoneToastView: View {
    @Environment(AppState.self) private var appState

    @State private var isPresented = false

    var body: some View {
        ZStack(alignment: .top) {
            if isPresented, let event = appState.pendingMilestoneToast {
                toastContent(event)
                    .padding(.top, 60)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(false)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: isPresented)
        .onChange(of: appState.pendingMilestoneToast?.id) { _, newId in
            guard newId != nil else {
                isPresented = false
                return
            }
            // 500ms delay so the type-aware "Logged" toast lands first.
            Task {
                try? await Task.sleep(for: .milliseconds(500))
                withAnimation { isPresented = true }
                try? await Task.sleep(for: .seconds(3))
                withAnimation { isPresented = false }
                try? await Task.sleep(for: .milliseconds(400))
                appState.dismissMilestoneToast()
            }
        }
    }

    private func toastContent(_ event: MilestoneToastEvent) -> some View {
        Text(event.message)
            .font(SikaTheme.Typography.sans(15, weight: .semibold))
            .foregroundStyle(SikaTheme.Color.foreground)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(SikaTheme.Color.card)
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
            )
            .overlay(
                Capsule()
                    .stroke(SikaTheme.Color.sikaAccent.opacity(0.4), lineWidth: 1)
            )
    }
}
