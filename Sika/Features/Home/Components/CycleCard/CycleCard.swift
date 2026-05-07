import SwiftUI

/// Heritage-themed cycle card. Phase 1 ships with sankofa theme only.
/// Additional themes (gye_nyame, adinkrahene, copper, emerald, amber, obsidian)
/// already have palettes in HeritageCardTheme; their motif renderers ship in
/// Phase 6 polish.
struct CycleCard: View {
    let cycleNet: Decimal
    let userName: String?
    let theme: HeritageCardTheme
    var currencyCode: String = "GHS"

    private var palette: HeritagePalette { theme.palette }

    var body: some View {
        ZStack {
            // Base background
            RoundedRectangle(cornerRadius: 24)
                .fill(palette.background)

            // Subtle gradient overlay for depth
            LinearGradient(
                colors: [Color.white.opacity(0.06), Color.clear, Color.black.opacity(0.18)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 24))

            // Top-right motif
            VStack {
                HStack {
                    Spacer()
                    motif
                        .padding(.trailing, SikaTheme.Spacing.lg)
                        .padding(.top, SikaTheme.Spacing.lg)
                }
                Spacer()
            }

            // Top-left chip
            VStack {
                HStack {
                    EMVChip(
                        primary: palette.chipPrimary,
                        secondary: palette.chipSecondary,
                        size: 38
                    )
                    .padding(.leading, SikaTheme.Spacing.lg)
                    .padding(.top, SikaTheme.Spacing.lg)
                    Spacer()
                }
                Spacer()
            }

            // Center-left amount
            HStack {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer()
                    Text(formattedNet)
                        .font(SikaTheme.Typography.displayDigit(36))
                        .foregroundStyle(palette.balanceText)
                        .padding(.leading, SikaTheme.Spacing.lg)
                    Spacer()
                }
                Spacer()
            }

            // Bottom row: name + SIKA wordmark
            VStack {
                Spacer()
                HStack(alignment: .bottom) {
                    if let name = displayName {
                        Text(name.uppercased())
                            .font(SikaTheme.Typography.mono(11, weight: .bold))
                            .foregroundStyle(palette.nameText.opacity(0.85))
                            .tracking(1.5)
                            .lineLimit(1)
                            .padding(.leading, SikaTheme.Spacing.lg)
                    }
                    Spacer()
                    Text("SIKA")
                        .font(SikaTheme.Typography.mono(13, weight: .bold))
                        .foregroundStyle(palette.brandText)
                        .tracking(2)
                        .padding(.trailing, SikaTheme.Spacing.lg)
                }
                .padding(.bottom, SikaTheme.Spacing.lg)
            }
        }
        .aspectRatio(1.586, contentMode: .fit)
        .shadow(color: .black.opacity(0.18), radius: 14, y: 8)
    }

    @ViewBuilder
    private var motif: some View {
        switch theme {
        case .sankofa:
            SankofaMotif(strokeColor: palette.motif, size: 88)
        default:
            // Phase 6: per-theme motif renderers. For now, all non-sankofa themes
            // render the sankofa motif as a placeholder.
            SankofaMotif(strokeColor: palette.motif, size: 88)
        }
    }

    private var formattedNet: String {
        CurrencyFormatter.format(cycleNet, code: currencyCode)
    }

    private var displayName: String? {
        guard let name = userName?.trimmingCharacters(in: .whitespaces),
              !name.isEmpty else { return nil }
        return name
    }
}
