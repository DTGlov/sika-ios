import SwiftUI

/// Settings section displaying the user's current card theme + a
/// "Change card" button that opens the theme picker sheet.
/// Mirror of src/components/settings/card-theme-picker.tsx.
struct CardStyleSection: View {
    @Environment(AppState.self) private var appState
    @State private var pickerOpen = false

    private var theme: HeritageCardTheme { appState.cardTheme }

    private var previewName: String {
        if case .authenticated(let profile) = appState.flow,
           let name = profile.fullName, !name.isEmpty {
            return name.uppercased()
        }
        return "YOUR NAME"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text("Card Style")
                    .font(SikaTheme.Typography.sans(16, weight: .semibold))
                    .foregroundStyle(SikaTheme.Color.foreground)

                Spacer()

                Button {
                    pickerOpen = true
                } label: {
                    Text("Change card")
                        .font(SikaTheme.Typography.sans(14, weight: .semibold))
                        .foregroundStyle(SikaTheme.Color.sikaAccent)
                }
                .buttonStyle(.plain)
            }

            Text(theme.subtitleLine)
                .font(SikaTheme.Typography.sans(12))
                .foregroundStyle(SikaTheme.Color.mutedForeground)
                .padding(.bottom, 12)

            // Live preview — uses the same CycleCard from Home.
            CycleCard(
                cycleNet: 2426,
                userName: previewName,
                theme: theme,
                currencyCode: appState.currencyCode
            )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(SikaTheme.Color.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(SikaTheme.Color.border, lineWidth: 1)
                )
        )
        .sheet(isPresented: $pickerOpen) {
            ThemePickerSheet(
                currentTheme: theme,
                onPick: { picked in
                    Task { await appState.updateCardTheme(picked) }
                }
            )
            .presentationDetents([.medium, .large])
        }
    }
}
