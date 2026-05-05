import SwiftUI

struct ToastView: View {
    let toast: Toast
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: SikaTheme.Spacing.sm) {
            Image(systemName: toast.kind.icon)
                .foregroundStyle(toast.kind.tint)
            Text(toast.message)
                .font(SikaTheme.Typography.sans(14))
                .foregroundStyle(SikaTheme.Color.foreground)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, SikaTheme.Spacing.lg)
        .padding(.vertical, SikaTheme.Spacing.md)
        .background(SikaTheme.Color.card)
        .overlay(
            RoundedRectangle(cornerRadius: SikaTheme.Radius.xl)
                .stroke(SikaTheme.Color.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: SikaTheme.Radius.xl))
        .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
        .padding(.horizontal, SikaTheme.Spacing.lg)
        .onTapGesture(perform: onTap)
    }
}

struct ToastOverlay: ViewModifier {
    @Environment(ToastManager.self) private var toasts

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if let toast = toasts.current {
                ToastView(toast: toast) { toasts.dismiss() }
                    .padding(.top, SikaTheme.Spacing.xs)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: toasts.current)
            }
        }
    }
}

extension View {
    func sikaToastOverlay() -> some View { modifier(ToastOverlay()) }
}
