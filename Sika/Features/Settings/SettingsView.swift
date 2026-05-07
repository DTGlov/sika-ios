import SwiftUI

/// Minimal Settings sheet. Phase 1.5 ships sign-out only.
/// Full Settings tab rebuild ships later with profile, preferences,
/// category management, income sources, and danger zone.
struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Settings")
                    .font(SikaTheme.Typography.sans(28, weight: .bold))
                    .foregroundStyle(SikaTheme.Color.foreground)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(SikaTheme.Color.foreground)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(SikaTheme.Color.muted)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, SikaTheme.Spacing.lg)
            .padding(.top, SikaTheme.Spacing.lg)
            .padding(.bottom, SikaTheme.Spacing.md)

            Spacer()

            SikaPrimaryButton(
                title: "Sign out",
                isLoading: appState.isPerformingAuthAction,
                isEnabled: !appState.isPerformingAuthAction
            ) {
                Task {
                    await appState.signOut()
                    // Sheet auto-dismisses because the auth flow change
                    // unmounts AuthenticatedRootView, but call dismiss() too
                    // for the case where signOut completes synchronously.
                    dismiss()
                }
            }
            .padding(.horizontal, SikaTheme.Spacing.lg)
            .padding(.bottom, SikaTheme.Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SikaTheme.Color.background)
    }
}
