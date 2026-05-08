import SwiftUI

/// Loading state during the LLM call.
/// Gold ring spinner + "Sika is thinking..." caption.
struct DecisionLoadingView: View {
    @State private var rotation: Double = 0

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(
                    SikaTheme.Color.sikaAccent,
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .frame(width: 40, height: 40)
                .rotationEffect(.degrees(rotation))
                .onAppear {
                    withAnimation(
                        .linear(duration: 1.0).repeatForever(autoreverses: false)
                    ) {
                        rotation = 360
                    }
                }

            Text("Sika is thinking...")
                .font(SikaTheme.Typography.sans(14))
                .foregroundStyle(SikaTheme.Color.mutedForeground)

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, minHeight: 280)
    }
}
