import SwiftUI

/// One of the 7 heritage card themes for the cycle card.
/// Source of truth: web app types/card-theme.ts. Keep in sync.
enum HeritageCardTheme: String, CaseIterable, Identifiable, Codable {
    case sankofa
    case gyeNyame = "gye_nyame"
    case adinkrahene
    case copper
    case emerald
    case amber
    case obsidian

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sankofa: return "Sankofa"
        case .gyeNyame: return "Gye Nyame"
        case .adinkrahene: return "Adinkrahene"
        case .copper: return "Copper"
        case .emerald: return "Emerald"
        case .amber: return "Amber"
        case .obsidian: return "Obsidian"
        }
    }

    var meaning: String? {
        switch self {
        case .sankofa: return "Learn from the past"
        case .gyeNyame: return "Except God"
        case .adinkrahene: return "Chief of symbols"
        default: return nil
        }
    }

    var palette: HeritagePalette {
        switch self {
        case .sankofa:
            return HeritagePalette(
                background: Color(hex: 0x0D1929),
                motif: Color(hex: 0xD4A017),
                chipPrimary: Color(hex: 0xC9A94A),
                chipSecondary: Color(hex: 0xA88938),
                balanceText: Color(hex: 0xE8D9B8),
                nameText: Color(hex: 0xE8D9B8),
                brandText: Color(hex: 0xD4A017)
            )
        case .gyeNyame:
            return HeritagePalette(
                background: Color(hex: 0x3E0F14),
                motif: Color(hex: 0xC8C8D0),
                chipPrimary: Color(hex: 0xBDBDC5),
                chipSecondary: Color(hex: 0x9B9BA3),
                balanceText: Color(hex: 0xE8E8EC),
                nameText: Color(hex: 0xE8E8EC),
                brandText: Color(hex: 0xC8C8D0)
            )
        case .adinkrahene:
            return HeritagePalette(
                background: Color(hex: 0x2A1339),
                motif: Color(hex: 0xD4A017),
                chipPrimary: Color(hex: 0xC9A94A),
                chipSecondary: Color(hex: 0xA88938),
                balanceText: Color(hex: 0xE8D9B8),
                nameText: Color(hex: 0xE8D9B8),
                brandText: Color(hex: 0xD4A017)
            )
        case .copper:
            return HeritagePalette(
                background: Color(hex: 0x1A1A1D),
                motif: Color(hex: 0xC87533),
                chipPrimary: Color(hex: 0xB88050),
                chipSecondary: Color(hex: 0x8F5F3A),
                balanceText: Color(hex: 0xE8D4B8),
                nameText: Color(hex: 0xE8D4B8),
                brandText: Color(hex: 0xC87533)
            )
        case .emerald:
            return HeritagePalette(
                background: Color(hex: 0x0F2E1F),
                motif: Color(hex: 0xE8DCB4),
                chipPrimary: Color(hex: 0xC9A94A),
                chipSecondary: Color(hex: 0xA88938),
                balanceText: Color(hex: 0xEFE8D0),
                nameText: Color(hex: 0xEFE8D0),
                brandText: Color(hex: 0xE8DCB4)
            )
        case .amber:
            return HeritagePalette(
                background: Color(hex: 0x0D1929),
                motif: Color(hex: 0xE0A040),
                chipPrimary: Color(hex: 0xC9A94A),
                chipSecondary: Color(hex: 0xA88938),
                balanceText: Color(hex: 0xE8D9B8),
                nameText: Color(hex: 0xE8D9B8),
                brandText: Color(hex: 0xE0A040)
            )
        case .obsidian:
            return HeritagePalette(
                background: Color(hex: 0x0E1A2E),
                motif: Color(hex: 0xC87533),
                chipPrimary: Color(hex: 0xB88050),
                chipSecondary: Color(hex: 0x8F5F3A),
                balanceText: Color(hex: 0xE8D4B8),
                nameText: Color(hex: 0xE8D4B8),
                brandText: Color(hex: 0xC87533)
            )
        }
    }
}

struct HeritagePalette {
    let background: SwiftUI.Color
    let motif: SwiftUI.Color
    let chipPrimary: SwiftUI.Color
    let chipSecondary: SwiftUI.Color
    let balanceText: SwiftUI.Color
    let nameText: SwiftUI.Color
    let brandText: SwiftUI.Color
}
