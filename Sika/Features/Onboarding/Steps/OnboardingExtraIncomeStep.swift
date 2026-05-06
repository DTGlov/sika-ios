import SwiftUI

struct OnboardingExtraIncomeStep: View {
    @Bindable var viewModel: OnboardingViewModel

    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: SikaTheme.Spacing.sm),
        GridItem(.flexible(), spacing: SikaTheme.Spacing.sm),
    ]

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
                Text("Any other income?")
                    .font(SikaTheme.Typography.sans(22, weight: .bold))
                    .foregroundStyle(SikaTheme.Color.foreground)
                Text("Add more sources or skip — you can always add them in Settings")
                    .font(SikaTheme.Typography.sans(14))
                    .foregroundStyle(SikaTheme.Color.mutedForeground)
            }

            LazyVGrid(columns: columns, spacing: SikaTheme.Spacing.sm) {
                ForEach(OnboardingViewModel.extraTemplates) { template in
                    templateCell(for: template)
                }
            }

            if !viewModel.extraSources.isEmpty {
                VStack(alignment: .leading, spacing: SikaTheme.Spacing.xs) {
                    Text("Added")
                        .font(SikaTheme.Typography.sans(13, weight: .semibold))
                        .foregroundStyle(SikaTheme.Color.foreground)
                    ForEach(viewModel.extraSources) { source in
                        addedRow(source)
                    }
                }
            }

            SikaPrimaryButton(
                title: viewModel.extraSources.isEmpty ? "Skip for now" : "Continue"
            ) {
                viewModel.goNext()
            }
        }
    }

    @ViewBuilder
    private func templateCell(for template: OnboardingViewModel.ExtraTemplate) -> some View {
        let isAdded = viewModel.extraSources.contains { $0.templateKey == template.id }
        let isActive = viewModel.activeExtraTemplateKey == template.id

        VStack(alignment: .leading, spacing: SikaTheme.Spacing.xs) {
            SikaChip(
                title: template.name,
                subtitle: template.frequency.compactName,
                isSelected: isAdded || isActive,
                isDisabled: isAdded,
                trailingIcon: isAdded ? "checkmark" : nil
            ) {
                viewModel.tapExtraTemplate(template)
            }

            if isActive {
                SikaTextField(
                    label: "Amount",
                    text: $viewModel.extraInputAmount,
                    kind: .decimal,
                    placeholder: "0.00"
                )
                HStack(spacing: SikaTheme.Spacing.xs) {
                    Button("Cancel") { viewModel.cancelExtraInput() }
                        .font(SikaTheme.Typography.sans(13, weight: .semibold))
                        .foregroundStyle(SikaTheme.Color.mutedForeground)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(SikaTheme.Color.muted)
                        .clipShape(RoundedRectangle(cornerRadius: SikaTheme.Radius.md))
                    Button("Add") { viewModel.confirmExtraAmount(template) }
                        .font(SikaTheme.Typography.sans(13, weight: .semibold))
                        .foregroundStyle(SikaTheme.Color.primaryForeground)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(SikaTheme.Color.primary)
                        .clipShape(RoundedRectangle(cornerRadius: SikaTheme.Radius.md))
                }
            }
        }
    }

    @ViewBuilder
    private func addedRow(_ source: TempIncomeSource) -> some View {
        HStack(spacing: SikaTheme.Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(source.name)
                    .font(SikaTheme.Typography.sans(14, weight: .semibold))
                    .foregroundStyle(SikaTheme.Color.foreground)
                Text(CurrencyFormatter.format(source.amount, code: viewModel.selectedCurrencyCode) + " · " + source.frequency.displayName)
                    .font(SikaTheme.Typography.sans(12))
                    .foregroundStyle(SikaTheme.Color.mutedForeground)
            }
            Spacer(minLength: 0)
            Button {
                viewModel.removeExtra(templateKey: source.templateKey)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(SikaTheme.Color.mutedForeground)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, SikaTheme.Spacing.md)
        .padding(.vertical, SikaTheme.Spacing.sm)
        .background(SikaTheme.Color.card)
        .overlay(
            RoundedRectangle(cornerRadius: SikaTheme.Radius.md)
                .stroke(SikaTheme.Color.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: SikaTheme.Radius.md))
    }
}
