import SwiftUI
import UIKit

/// User's theme preference — Light or Dark only. NO System/Auto option.
/// Matches web's theme picker: explicit choice, no OS-driven default.
///
/// Stored on `profiles.theme_preference` as a lowercase string ("light"|"dark").
enum SystemTheme: String, Codable, CaseIterable, Equatable {
    case light, dark

    var displayName: String {
        switch self {
        case .light: return "Light"
        case .dark:  return "Dark"
        }
    }

    var systemImage: String {
        switch self {
        case .light: return "sun.max"
        case .dark:  return "moon"
        }
    }

    /// Bridges to UIKit's `UIUserInterfaceStyle` for `UIWindow` overrides.
    var uiUserInterfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .light: return .light
        case .dark:  return .dark
        }
    }
}

// MARK: - Profile bridge

extension Profile {
    /// Typed accessor for `themePreference`. Falls back to `.light` for any
    /// value that doesn't match the enum (defensive for legacy "system" rows).
    var themePreferenceValue: SystemTheme {
        SystemTheme(rawValue: themePreference) ?? .light
    }
}
