import SwiftUI

/// Settings sheet. Phase 1.5 shipped sign-out only; Phase 6 adds the
/// "Card Style" section + dashboard_card_theme_available HintCard.
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

            ScrollView {
                VStack(spacing: SikaTheme.Spacing.md) {
                    HintCard(
                        hintId: .cardThemeAvailable,
                        title: "Customize your card",
                        message: "Choose from 7 heritage-themed card styles inspired by Adinkra symbols and Ghanaian craft. Tap 'Change card' to browse."
                    )

                    CardStyleSection()
                }
                .padding(.horizontal, SikaTheme.Spacing.lg)
                .padding(.top, SikaTheme.Spacing.sm)
                .padding(.bottom, SikaTheme.Spacing.lg)
            }

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
