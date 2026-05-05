import SwiftUI

struct Toast: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let kind: Kind

    enum Kind {
        case info, success, error

        var icon: String {
            switch self {
            case .info: return "info.circle.fill"
            case .success: return "checkmark.circle.fill"
            case .error: return "exclamationmark.triangle.fill"
            }
        }

        var tint: Color {
            switch self {
            case .info: return SikaTheme.Color.sikaAccent
            case .success: return SikaTheme.Color.sikaSuccess
            case .error: return SikaTheme.Color.destructive
            }
        }
    }
}
