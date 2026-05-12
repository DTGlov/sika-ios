import SwiftUI

/// Global amber warning toast (T3). Rendered as an overlay on
/// `AuthenticatedRootView` whenever `AppState.pendingWarningToast` is set.
/// Distinct from `ToastManager` because `ToastManager` is a local-scope
/// queue while this toast is fired from the wizard after its own dismiss —
/// it can't reach a TabBar-local `ToastManager` at that point.
///
/// Auto-dismisses after 3s; calls `AppState.dismissWarningToast()` to clear
/// the published state.
struct WarningToastView: View {
    @Environment(AppState.self) private var appState

    @State private var isPresented = false

    private let amberColor = Color(hex: 0xFBBF24)

    var body: some View {
        ZStack(alignment: .top) {
            if isPresented, let event = appState.pendingWarningToast {
                toastContent(event)
                    .padding(.top, 60)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(false)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: isPresented)
        .onChange(of: appState.pendingWarningToast?.id) { _, newId in
            guard newId != nil else {
                isPresented = false
                return
            }
            Task {
                withAnimation { isPresented = true }
                try? await Task.sleep(for: .seconds(3))
                withAnimation { isPresented = false }
                try? await Task.sleep(for: .milliseconds(400))
                appState.dismissWarningToast()
            }
        }
    }

    private func toastContent(_ event: WarningToastEvent) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(amberColor)
                .font(.system(size: 16, weight: .semibold))
            Text(event.message)
                .font(SikaTheme.Typography.sans(14, weight: .medium))
                .foregroundStyle(SikaTheme.Color.foreground)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(SikaTheme.Color.card)
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        )
        .overlay(
            Capsule()
                .stroke(amberColor.opacity(0.4), lineWidth: 1)
        )
        .padding(.horizontal, 24)
    }
}
