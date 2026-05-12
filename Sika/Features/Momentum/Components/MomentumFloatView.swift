import SwiftUI

/// "+N pts" capsule bubble that floats up + fades out, then self-dismisses
/// via the supplied callback. One per `MomentumFloatEvent` in
/// `AppState.pendingMomentumFloats`. Rendered by `MomentumFloatContainer`.
///
/// Animation: 1.2s upward translation paired with a delayed opacity fade.
/// Self-dismiss fires at 1.5s so the container removes it from the queue.
struct MomentumFloatView: View {
    let event: MomentumFloatEvent
    let onDismiss: (UUID) -> Void

    @State private var yOffset: CGFloat = 0
    @State private var opacity: Double = 1.0

    private let goldColor = Color(hex: 0xD4AF37)

    var body: some View {
        Text("+\(event.points) pts")
            .font(SikaTheme.Typography.sans(16, weight: .semibold))
            .foregroundStyle(goldColor)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(SikaTheme.Color.background)
                    .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
            )
            .overlay(
                Capsule()
                    .stroke(goldColor.opacity(0.3), lineWidth: 1)
            )
            .offset(y: yOffset)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeOut(duration: 1.2)) {
                    yOffset = -240
                }
                withAnimation(.easeOut(duration: 0.5).delay(1.0)) {
                    opacity = 0
                }
                Task {
                    try? await Task.sleep(for: .milliseconds(1500))
                    onDismiss(event.id)
                }
            }
    }
}
