import SwiftUI

/// Tile that opens the currency picker sub-route.
struct CurrencyTile: View {
    @Environment(AppState.self) private var appState

    private var currentCode: String {
        if case .authenticated(let profile) = appState.flow {
            return profile.currency
        }
        return "GHS"
    }

    private var currentSymbol: String {
        CurrencyCatalog.currency(forCode: currentCode)?.symbol ?? currentCode
    }

    var body: some View {
        SettingsCard(
            title: "Currency",
            subtitle: "Used for all amounts shown across the app."
        ) {
            NavigationLink {
                CurrencyPickerView(currentCode: currentCode)
            } label: {
                HStack(spacing: 8) {
                    Text(currentCode)
                        .font(SikaTheme.Typography.sans(14, weight: .semibold))
                        .foregroundStyle(SikaTheme.Color.foreground)
                    Text("·")
                        .foregroundStyle(SikaTheme.Color.mutedForeground.opacity(0.6))
                    Text(currentSymbol)
                        .font(SikaTheme.Typography.sans(14))
                        .foregroundStyle(SikaTheme.Color.mutedForeground)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(SikaTheme.Color.mutedForeground.opacity(0.7))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(SikaTheme.Color.muted)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
    }
}
