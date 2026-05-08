import SwiftUI

/// Heritage-themed cycle card. Phase 6 ships all 7 motifs.
/// Themes: sankofa, gye_nyame, adinkrahene, copper, emerald, amber, obsidian.
/// Each motif is a stylized SwiftUI Canvas approximation of the web SVG —
/// faithful enough to be recognizable; not pixel-perfect ports.
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
        case .gyeNyame:
            GyeNyameMotif(strokeColor: palette.motif, size: 88)
        case .adinkrahene:
            AdinkraheneMotif(strokeColor: palette.motif, size: 88)
        case .copper:
            CopperMotif(strokeColor: palette.motif, size: 96)
        case .emerald:
            EmeraldMotif(strokeColor: palette.motif, width: 180, height: 70)
        case .amber:
            AmberMotif(strokeColor: palette.motif, size: 110)
        case .obsidian:
            ObsidianMotif(strokeColor: palette.motif, size: 88)
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
