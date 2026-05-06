import SwiftUI

/// Sika's floating action button. Positioned by the parent view; this struct
/// only renders the button itself (halo + body + icon + press feedback).
struct FloatingActionButton: View {
    let action: () -> Void
    var icon: String = "plus"
    var diameter: CGFloat = 56

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(SikaTheme.Color.sikaAccent.opacity(0.18))
                    .frame(width: diameter + 20, height: diameter + 20)
                    .blur(radius: 6)

                Circle()
                    .fill(SikaTheme.Color.sikaAccent)
                    .frame(width: diameter, height: diameter)
                    .shadow(color: SikaTheme.Color.sikaAccent.opacity(0.4),
                            radius: 12, y: 4)

                Image(systemName: icon)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(SikaTheme.Color.primaryForeground)
            }
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7),
                       value: isPressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .accessibilityLabel("Add transaction")
    }
}
