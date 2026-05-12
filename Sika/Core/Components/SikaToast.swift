import SwiftUI

/// Reusable inline toast. Slides in from top, auto-dismisses after a duration.
/// Three variants: success (gold checkmark), info (no icon), error (destructive icon).
///
/// Use the `.sikaToast(isShown:message:variant:duration:)` view modifier on the
/// surface that should host the overlay.
struct SikaToast: View {
    enum Variant {
        case success
        case successGreen
        case info
        case error
    }

    let message: String
    var variant: Variant = .info

    var body: some View {
        HStack(spacing: SikaTheme.Spacing.xs) {
            icon
            Text(message)
                .font(SikaTheme.Typography.sans(14, weight: .semibold))
                .foregroundStyle(SikaTheme.Color.foreground)
        }
        .padding(.horizontal, SikaTheme.Spacing.md)
        .padding(.vertical, SikaTheme.Spacing.sm)
        .background(SikaTheme.Color.card)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
    }

    @ViewBuilder
    private var icon: some View {
        switch variant {
        case .success:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(SikaTheme.Color.sikaAccent)
                .font(.system(size: 16, weight: .semibold))
        case .successGreen:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(SikaTheme.Color.sikaSuccess)
                .font(.system(size: 16, weight: .semibold))
        case .info:
            EmptyView()
        case .error:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(SikaTheme.Color.destructive)
                .font(.system(size: 16, weight: .semibold))
        }
    }
}

/// View modifier for showing a toast that auto-dismisses.
struct SikaToastModifier: ViewModifier {
    @Binding var isShown: Bool
    let message: String
    var variant: SikaToast.Variant = .info
    var duration: Duration = .seconds(2)

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if isShown {
                    SikaToast(message: message, variant: variant)
                        .padding(.top, SikaTheme.Spacing.lg)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .task {
                            try? await Task.sleep(for: duration)
                            withAnimation { isShown = false }
                        }
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: isShown)
    }
}

extension View {
    func sikaToast(
        isShown: Binding<Bool>,
        message: String,
        variant: SikaToast.Variant = .info,
        duration: Duration = .seconds(2)
    ) -> some View {
        modifier(SikaToastModifier(isShown: isShown, message: message, variant: variant, duration: duration))
    }
}
