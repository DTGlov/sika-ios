import SwiftUI

struct OnboardingPrimaryIncomeStep: View {
    @Bindable var viewModel: OnboardingViewModel

    @State private var monthlyDayInput: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: SikaTheme.Spacing.lg) {
            Button {
                viewModel.goBack()
            } label: {
                HStack(spacing: SikaTheme.Spacing.xs) {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .font(SikaTheme.Typography.sans(14, weight: .semibold))
                .foregroundStyle(SikaTheme.Color.mutedForeground)
            }

            VStack(alignment: .leading, spacing: SikaTheme.Spacing.xs) {
                Text("Primary income")
                    .font(SikaTheme.Typography.sans(22, weight: .bold))
                    .foregroundStyle(SikaTheme.Color.foreground)
                Text("Your main source of earnings")
                    .font(SikaTheme.Typography.sans(14))
                    .foregroundStyle(SikaTheme.Color.mutedForeground)
            }

            SikaTextField(
                label: "Name",
                text: $viewModel.primaryName,
                kind: .text,
                placeholder: "e.g. Salary"
            )

            SikaTextField(
                label: "Amount",
                text: $viewModel.primaryAmountInput,
                kind: .decimal,
                placeholder: "0.00 \(CurrencyFormatter.symbol(forCode: viewModel.selectedCurrencyCode))"
            )

            VStack(alignment: .leading, spacing: SikaTheme.Spacing.sm) {
                Text("Frequency")
                    .font(SikaTheme.Typography.sans(13, weight: .semibold))
                    .foregroundStyle(SikaTheme.Color.foreground)

                HStack(spacing: SikaTheme.Spacing.xs) {
                    ForEach(IncomeFrequency.allCases) { freq in
                        SikaChip(
                            title: freq.compactName,
                            isSelected: viewModel.primaryFrequency == freq
                        ) {
                            viewModel.primaryFrequency = freq
                            if !freq.requiresExpectedDay {
                                viewModel.primaryExpectedDay = nil
                            }
                        }
                    }
                }
            }

            expectedDayBlock

            Text(viewModel.primaryFrequency.expectedDayHint)
                .font(SikaTheme.Typography.sans(12))
                .foregroundStyle(SikaTheme.Color.mutedForeground)

            SikaPrimaryButton(
                title: "Continue",
                isEnabled: viewModel.canSubmitPrimary
            ) {
                _ = viewModel.submitPrimary()
            }
        }
    }

    @ViewBuilder
    private var expectedDayBlock: some View {
        switch viewModel.primaryFrequency {
        case .monthly:
            VStack(alignment: .leading, spacing: SikaTheme.Spacing.xs) {
                SikaTextField(
                    label: "Day of month",
                    text: $monthlyDayInput,
                    kind: .decimal,
                    placeholder: "e.g. 25"
                )
            }
            .onChange(of: monthlyDayInput) { _, newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespaces)
                if let day = Int(trimmed), (1...31).contains(day) {
                    viewModel.primaryExpectedDay = day
                } else {
                    viewModel.primaryExpectedDay = nil
                }
            }
            .onAppear {
                if let day = viewModel.primaryExpectedDay {
                    monthlyDayInput = String(day)
                }
            }
        case .weekly, .biweekly:
            VStack(alignment: .leading, spacing: SikaTheme.Spacing.xs) {
                Text("Day of week")
                    .font(SikaTheme.Typography.sans(13, weight: .semibold))
                    .foregroundStyle(SikaTheme.Color.foreground)
                DayOfWeekPicker(selection: $viewModel.primaryExpectedDay)
            }
        case .irregular:
            EmptyView()
        }
    }
}
