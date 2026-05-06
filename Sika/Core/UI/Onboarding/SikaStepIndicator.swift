import SwiftUI

/// Animated step indicator. Active segment scales 1.5x; color via bucketNeeds (#00D9A3).
struct SikaStepIndicator: View {
    let totalSteps: Int
    let currentStep: Int

    var body: some View {
        HStack(spacing: SikaTheme.Spacing.xs) {
            ForEach(1...totalSteps, id: \.self) { index in
                Capsule()
                    .fill(index <= currentStep ? SikaTheme.Color.bucketNeeds : SikaTheme.Color.border)
                    .frame(height: 4)
                    .frame(maxWidth: .infinity)
                    .scaleEffect(x: index == currentStep ? 1.5 : 1.0, y: 1.0, anchor: .center)
                    .animation(.spring(response: 0.4, dampingFraction: 0.85), value: currentStep)
            }
        }
    }
}
