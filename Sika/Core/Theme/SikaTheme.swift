import SwiftUI

/// Sika brand design tokens.
/// Source of truth: web app globals.css. Keep in sync.
enum SikaTheme {
    enum Color {
        static let background = SwiftUI.Color(hex: 0xFBF7EE)
        static let foreground = SwiftUI.Color(hex: 0x0E1A2E)
        static let card = SwiftUI.Color(hex: 0xFFFFFF)

        static let primary = SwiftUI.Color(hex: 0xD4A017)
        static let primaryForeground = SwiftUI.Color(hex: 0x0E1A2E)

        static let secondary = SwiftUI.Color(hex: 0xF1EFE6)
        static let muted = SwiftUI.Color(hex: 0xF1EFE6)
        static let mutedForeground = SwiftUI.Color(hex: 0x6B7A8D)

        /// Higher-contrast color for input placeholders. WCAG AA compliant
        /// against both card (#FFFFFF) and input (#F1EFE6) backgrounds.
        /// Don't use this for secondary text — that's mutedForeground.
        static let placeholderText = SwiftUI.Color(hex: 0x525E70)

        static let border = SwiftUI.Color(hex: 0xE2DCCF)

        static let destructive = SwiftUI.Color(hex: 0xF43F5E)

        static let sikaBase = SwiftUI.Color(hex: 0x0E1A2E)
        static let sikaElevated = SwiftUI.Color(hex: 0x162540)
        static let sikaHover = SwiftUI.Color(hex: 0x1E2F47)
        static let sikaText = SwiftUI.Color(hex: 0xF8ECC2)
        static let sikaTextSecondary = SwiftUI.Color(hex: 0x8A9BB5)
        static let sikaAccent = SwiftUI.Color(hex: 0xD4A017)
        static let sikaAccentHover = SwiftUI.Color(hex: 0xB8891A)
        static let sikaAccentGlow = SwiftUI.Color(hex: 0xE8B520)
        static let sikaSuccess = SwiftUI.Color(hex: 0x00D9A3)
        static let sikaWarning = SwiftUI.Color(hex: 0xFBBF24)
        static let sikaDanger = SwiftUI.Color(hex: 0xF43F5E)
        static let sikaBorderStrong = SwiftUI.Color(hex: 0x1E3050)

        static let bucketNeeds = SwiftUI.Color(hex: 0x00D9A3)
        static let bucketWants = SwiftUI.Color(hex: 0xFBBF24)
        static let bucketSavings = SwiftUI.Color(hex: 0x60A5FA)
    }

    enum Radius {
        static let sm: CGFloat = 7.2
        static let md: CGFloat = 9.6
        static let lg: CGFloat = 12
        static let xl: CGFloat = 16.8
        static let xl2: CGFloat = 21.6
        static let xl3: CGFloat = 26.4
        static let xl4: CGFloat = 31.2

        static let virtualCard: CGFloat = 20
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xl2: CGFloat = 32
        static let xl3: CGFloat = 48
    }

    enum Typography {
        static let sansFamily = "Geist"
        static let monoFamily = "GeistMono"

        static func sans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
            let postScriptName: String
            switch weight {
            case .bold: postScriptName = "Geist-Bold"
            case .semibold: postScriptName = "Geist-SemiBold"
            default: postScriptName = "Geist-Regular"
            }
            return Font.custom(postScriptName, size: size)
        }

        static func mono(_ size: CGFloat) -> Font {
            return Font.custom("GeistMono-Regular", size: size)
        }
    }
}

extension SwiftUI.Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}
