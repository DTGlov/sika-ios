import SwiftUI

/// 3-segment gold step indicator for the Add Transaction wizard.
/// Distinct from the 5-segment variant used in onboarding.
struct StepIndicator3: View {
    let currentStep: Int

    var body: some View {
        HStack(spacing: SikaTheme.Spacing.sm) {
            ForEach(1...3, id: \.self) { index in
                Capsule()
                    .fill(index <= currentStep
                        ? SikaTheme.Color.sikaAccent
                        : SikaTheme.Color.muted)
                    .frame(height: 4)
                    .frame(maxWidth: .infinity)
                    .animation(.spring(response: 0.4, dampingFraction: 0.85),
                               value: currentStep)
            }
        }
    }
}
