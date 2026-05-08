import SwiftUI

/// Theme picker modal sheet. 2-column grid of mini cards.
/// Tap → optimistic update via AppState.updateCardTheme + dismiss.
/// Mirror of web's theme-picker dialog (src/components/settings/theme-picker.tsx).
struct ThemePickerSheet: View {
    let currentTheme: HeritageCardTheme
    let onPick: (HeritageCardTheme) -> Void

    @Environment(\.dismiss) private var dismiss

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(HeritageCardTheme.pickerOrder) { theme in
                        ThemePickerCard(
                            theme: theme,
                            isSelected: theme == currentTheme
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onPick(theme)
                            dismiss()
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(theme.displayName)
                        .accessibilityAddTraits(theme == currentTheme ? .isSelected : [])
                    }
                }
                .padding(20)

                Text("Inspired by Adinkra symbols and Ghanaian heritage.")
                    .font(SikaTheme.Typography.sans(12))
                    .foregroundStyle(SikaTheme.Color.mutedForeground)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 20)
            }
            .background(SikaTheme.Color.background)
            .navigationTitle("Choose your card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .sensoryFeedback(.selection, trigger: currentTheme)
    }
}

/// Mini card preview in the picker grid. NO chip, NO balance, NO user name —
/// only SIKA wordmark + theme name in bottom row. Aspect ratio 85.6/54.
struct ThemePickerCard: View {
    let theme: HeritageCardTheme
    let isSelected: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ZStack(alignment: .bottomLeading) {
                theme.palette.background

                // Re-use the full motif at a smaller size.
                miniMotif

                HStack(alignment: .lastTextBaseline) {
                    Text("SIKA")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1.4)
                        .foregroundStyle(theme.palette.brandText)
                    Spacer()
                    Text(theme.displayName)
                        .font(.system(size: 8))
                        .tracking(0.5)
                        .foregroundStyle(theme.palette.nameText.opacity(0.85))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .padding(8)
            }
            .aspectRatio(85.6 / 54, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        isSelected ? SikaTheme.Color.sikaAccent : Color.clear,
                        lineWidth: 2
                    )
            )

            if isSelected {
                ZStack {
                    Circle()
                        .fill(SikaTheme.Color.sikaAccent)
                        .frame(width: 20, height: 20)
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.black)
                }
                .padding(6)
            }
        }
    }

    @ViewBuilder
    private var miniMotif: some View {
        // Half the size of the Home card's motif. Pinned to the right edge
        // for the centered-origin motifs; full overlay for Copper/Emerald/Amber.
        switch theme {
        case .sankofa:
            HStack { Spacer(); SankofaMotif(strokeColor: theme.palette.motif, size: 44).padding(.trailing, 6) }
        case .gyeNyame:
            HStack { Spacer(); GyeNyameMotif(strokeColor: theme.palette.motif, size: 44).padding(.trailing, 6) }
        case .adinkrahene:
            HStack { Spacer(); AdinkraheneMotif(strokeColor: theme.palette.motif, size: 44).padding(.trailing, 6) }
        case .copper:
            CopperMotif(strokeColor: theme.palette.motif, size: 64)
        case .emerald:
            EmeraldMotif(strokeColor: theme.palette.motif, width: 120, height: 50)
        case .amber:
            AmberMotif(strokeColor: theme.palette.motif, size: 60)
        case .obsidian:
            HStack { Spacer(); ObsidianMotif(strokeColor: theme.palette.motif, size: 44).padding(.trailing, 6) }
        }
    }
}
