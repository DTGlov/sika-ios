import SwiftUI
import UIKit

extension Color {
    /// Initializer that returns different colors for light vs dark color scheme.
    /// Uses UIColor's dynamic provider under the hood so all SwiftUI consumers
    /// (including in Canvas, Image, etc.) automatically resolve correctly.
    init(light: Color, dark: Color) {
        self = Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(dark)
                : UIColor(light)
        })
    }
}
