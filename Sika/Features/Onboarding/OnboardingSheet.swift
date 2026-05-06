import SwiftUI

struct OnboardingSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel = OnboardingViewModel()

    private let incomeService = IncomeService()
    private let profileService = ProfileService()

    var body: some View {
        VStack(spacing: 0) {
            SikaStepIndicator(totalSteps: viewModel.totalSteps, currentStep: viewModel.step)
                .padding(.horizontal, SikaTheme.Spacing.lg)
                .padding(.top, SikaTheme.Spacing.lg)
                .padding(.bottom, SikaTheme.Spacing.md)

            ScrollView {
                Group {
                    switch viewModel.step {
                    case 1:
                        OnboardingIntroStep(viewModel: viewModel, onSkip: skip)
                    case 2:
                        OnboardingCurrencyStep(viewModel: viewModel, onSkip: skip)
                    case 3:
                        OnboardingPrimaryIncomeStep(viewModel: viewModel)
                    case 4:
                        OnboardingExtraIncomeStep(viewModel: viewModel)
                    default:
                        OnboardingReviewStep(viewModel: viewModel, onFinish: finish)
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.94)))
                .padding(.horizontal, SikaTheme.Spacing.lg)
                .padding(.vertical, SikaTheme.Spacing.lg)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SikaTheme.Color.background)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: viewModel.step)
    }

    private func skip() {
        appState.dismissOnboardingForSession()
        dismiss()
    }

    private func finish() {
        Task {
            await viewModel.finish(
                appState: appState,
                incomeService: incomeService,
                profileService: profileService
            )
            if viewModel.serverError == nil {
                dismiss()
            }
        }
    }
}
