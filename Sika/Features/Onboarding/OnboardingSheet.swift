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

            stepContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SikaTheme.Color.background)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: viewModel.step)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch viewModel.step {
        case 1:
            scrolling { OnboardingIntroStep(viewModel: viewModel, onSkip: skip) }
        case 2:
            // Currency step manages its own internal scrolling so the action
            // buttons stay pinned below the list at all times.
            OnboardingCurrencyStep(viewModel: viewModel, onSkip: skip)
                .transition(.opacity.combined(with: .scale(scale: 0.94)))
        case 3:
            scrolling { OnboardingPrimaryIncomeStep(viewModel: viewModel) }
        case 4:
            scrolling { OnboardingExtraIncomeStep(viewModel: viewModel) }
        default:
            scrolling { OnboardingReviewStep(viewModel: viewModel, onFinish: finish) }
        }
    }

    @ViewBuilder
    private func scrolling<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ScrollView {
            content()
                .transition(.opacity.combined(with: .scale(scale: 0.94)))
                .padding(.horizontal, SikaTheme.Spacing.lg)
                .padding(.vertical, SikaTheme.Spacing.lg)
        }
        .scrollDismissesKeyboard(.interactively)
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
