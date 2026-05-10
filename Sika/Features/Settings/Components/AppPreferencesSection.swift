import SwiftUI

/// Reset onboarding hints. Confirmation Alert before deleting.
struct AppPreferencesSection: View {
    @Environment(AppState.self) private var appState
    @Environment(ToastManager.self) private var toasts

    @State private var showConfirm = false
    @State private var isResetting = false

    var body: some View {
        SettingsCard(
            title: "App preferences",
            subtitle: "Show all dismissed hints again. Useful if you want a refresher."
        ) {
            Button {
                showConfirm = true
            } label: {
                HStack(spacing: 8) {
                    if isResetting {
                        ProgressView().scaleEffect(0.8)
                    } else {
                        Image(systemName: "arrow.counterclockwise")
                    }
                    Text("Reset onboarding hints")
                }
                .font(SikaTheme.Typography.sans(13, weight: .semibold))
                .foregroundStyle(SikaTheme.Color.foreground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(SikaTheme.Color.card)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(SikaTheme.Color.border, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(isResetting)
        }
        .alert("Reset all dismissed hints?", isPresented: $showConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                Task { await reset() }
            }
        } message: {
            Text("All onboarding hints will appear again throughout the app.")
        }
    }

    private func reset() async {
        isResetting = true
        defer { isResetting = false }
        do {
            try await appState.resetHints()
            toasts.show("Hints will appear again", kind: .success)
        } catch {
            toasts.show("Failed to reset hints", kind: .error)
        }
    }
}
