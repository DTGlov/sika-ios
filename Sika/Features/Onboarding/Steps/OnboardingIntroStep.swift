import SwiftUI

struct OnboardingIntroStep: View {
    let viewModel: OnboardingViewModel
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: SikaTheme.Spacing.xl) {
            Image(systemName: "sparkles")
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(SikaTheme.Color.sikaAccent)
                .frame(width: 64, height: 64)
                .background(SikaTheme.Color.sikaAccent.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: SikaTheme.Radius.xl))

            VStack(spacing: SikaTheme.Spacing.sm) {
                Text("How do you earn?")
                    .font(SikaTheme.Typography.sans(24, weight: .bold))
                    .foregroundStyle(SikaTheme.Color.foreground)
                Text("Let's set up your income")
                    .font(SikaTheme.Typography.sans(16))
                    .foregroundStyle(SikaTheme.Color.mutedForeground)
            }
            .multilineTextAlignment(.center)

            Text("Sika tracks multiple income sources — salary, allowances, side income — so your discipline math always reflects your real situation.")
                .font(SikaTheme.Typography.sans(14))
                .foregroundStyle(SikaTheme.Color.mutedForeground)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, SikaTheme.Spacing.md)

            VStack(spacing: SikaTheme.Spacing.sm) {
                SikaPrimaryButton(title: "Get started") {
                    viewModel.goNext()
                }

                Button("I'll do this later", action: onSkip)
                    .font(SikaTheme.Typography.sans(14, weight: .semibold))
                    .foregroundStyle(SikaTheme.Color.mutedForeground)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
