import SwiftUI

/// Phase S1 — Settings sheet orchestrator. Sections in display order:
/// Appearance · Currency · Haptics · Notifications · Income Sources (read-only)
/// · Card Style (Phase 6 reuse) · Total Income echo + Budget Month + Budget Split
/// · Categories (read-only) · App preferences · Sign out · Danger zone · Privacy.
///
/// Reached via the gear icon on Home's HomeTopBar (Phase 6 wiring); presented
/// as `.sheet`. The sheet is wrapped in NavigationStack so the Currency picker
/// can push as a sub-route.
struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    private var hasOnlyDefaultCats: Bool {
        // Treat "default" as: no user-created categories yet. The full hint
        // system on web uses category metadata not modeled on iOS — this is a
        // good-enough proxy and shows the hint sparingly.
        appState.categories.allSatisfy { $0.userId == nil }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    AppearanceSection()
                    CurrencyTile()
                    HapticsSection()
                    NotificationSettings()

                    if appState.incomeSources.isEmpty {
                        HintCard(
                            hintId: .settingsIncomeSources,
                            title: "Add your income sources",
                            message: "List where your money comes from each month so Sika can compute the right budget split for you."
                        )
                    }
                    IncomeSourcesSection()

                    HintCard(
                        hintId: .cardThemeAvailable,
                        title: "Customize your card",
                        message: "Choose from 7 heritage-themed card styles inspired by Adinkra symbols and Ghanaian craft. Tap 'Change card' to browse."
                    )
                    CardStyleSection()

                    BudgetConfigForm()

                    if hasOnlyDefaultCats {
                        HintCard(
                            hintId: .settingsCategories,
                            title: "Make categories yours",
                            message: "Add categories that match how you actually spend. You can always archive ones you don't use."
                        )
                    }
                    CategoriesSection()

                    AppPreferencesSection()
                    SignOutButton()
                    DangerZoneSection()
                    PrivacyPolicyLink()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .background(SikaTheme.Color.background)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(SikaTheme.Color.foreground)
                            .padding(8)
                            .background(SikaTheme.Color.muted)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
