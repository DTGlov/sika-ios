import SwiftUI

struct HapticsSection: View {
    @Environment(AppState.self) private var appState

    private let goldColor = Color(hex: 0xD4A017)

    private var enabled: Bool {
        if case .authenticated(let profile) = appState.flow {
            return profile.hapticsEnabled ?? true
        }
        return true
    }

    var body: some View {
        SettingsCard(
            title: "Haptics",
            subtitle: "Subtle feedback when you log transactions and reach milestones."
        ) {
            HStack {
                Text(enabled ? "Enabled" : "Disabled")
                    .font(SikaTheme.Typography.sans(13))
                    .foregroundStyle(SikaTheme.Color.mutedForeground)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { enabled },
                    set: { newValue in
                        Task { await appState.updateHapticsEnabled(newValue) }
                    }
                ))
                .labelsHidden()
                .tint(goldColor)
            }
        }
    }
}
