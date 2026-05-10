import SwiftUI

/// Light / Dark 2-tile picker. NO System/Auto option.
/// Active tile: gold accent border + 10% gold bg + gold-tinted icon and label.
struct AppearanceSection: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        SettingsCard(
            title: "Appearance",
            subtitle: "Choose your preferred colour scheme."
        ) {
            HStack(spacing: 8) {
                ForEach(SystemTheme.allCases, id: \.self) { theme in
                    ThemeTile(
                        theme: theme,
                        isActive: currentTheme == theme,
                        action: { Task { await appState.updateSystemTheme(theme) } }
                    )
                }
            }
        }
    }

    private var currentTheme: SystemTheme {
        if case .authenticated(let profile) = appState.flow {
            return profile.themePreferenceValue
        }
        return .light
    }
}

private struct ThemeTile: View {
    let theme: SystemTheme
    let isActive: Bool
    let action: () -> Void

    private let goldColor = Color(hex: 0xD4A017)

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: theme.systemImage)
                    .font(.system(size: 22))
                    .foregroundStyle(isActive ? goldColor : SikaTheme.Color.mutedForeground)
                Text(theme.displayName)
                    .font(SikaTheme.Typography.sans(12, weight: .semibold))
                    .foregroundStyle(isActive ? goldColor : SikaTheme.Color.foreground)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isActive ? goldColor.opacity(0.10) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isActive ? goldColor : SikaTheme.Color.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
