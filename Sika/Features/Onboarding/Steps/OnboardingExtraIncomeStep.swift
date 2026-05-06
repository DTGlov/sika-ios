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

            templateGridOrEdit
                .animation(.spring(response: 0.35, dampingFraction: 0.85),
                           value: viewModel.activeExtraTemplateKey)

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
    private var templateGridOrEdit: some View {
        if let activeKey = viewModel.activeExtraTemplateKey,
           let activeTemplate = OnboardingViewModel.extraTemplates.first(where: { $0.id == activeKey }) {
            ExtraIncomeEditCard(
                template: activeTemplate,
                amountInput: $viewModel.extraInputAmount,
                currencyCode: viewModel.selectedCurrencyCode,
                onConfirm: { viewModel.confirmExtraAmount(activeTemplate) },
                onCancel: { viewModel.cancelExtraInput() }
            )
            .transition(.scale(scale: 0.96).combined(with: .opacity))
        } else {
            LazyVGrid(columns: columns, spacing: SikaTheme.Spacing.sm) {
                ForEach(OnboardingViewModel.extraTemplates) { template in
                    ExtraTemplateChip(
                        template: template,
                        isAdded: viewModel.extraSources.contains { $0.templateKey == template.id },
                        onTap: { viewModel.tapExtraTemplate(template) }
                    )
                }
            }
            .transition(.scale(scale: 0.98).combined(with: .opacity))
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

private struct ExtraTemplateChip: View {
    let template: OnboardingViewModel.ExtraTemplate
    let isAdded: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: SikaTheme.Spacing.xs) {
                HStack {
                    Text(template.name)
                        .font(SikaTheme.Typography.sans(13, weight: .semibold))
                        .foregroundStyle(SikaTheme.Color.foreground)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                    if isAdded {
                        Image(systemName: "checkmark")
                            .foregroundStyle(SikaTheme.Color.sikaAccent)
                            .font(.system(size: 12, weight: .bold))
                    }
                }
                Text(template.frequency.displayName)
                    .font(SikaTheme.Typography.sans(12))
                    .foregroundStyle(SikaTheme.Color.mutedForeground)
            }
            .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
            .padding(SikaTheme.Spacing.md)
            .background(isAdded ? SikaTheme.Color.bucketNeeds.opacity(0.1) : SikaTheme.Color.muted)
            .overlay(
                RoundedRectangle(cornerRadius: SikaTheme.Radius.lg)
                    .stroke(isAdded ? SikaTheme.Color.bucketNeeds : SikaTheme.Color.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: SikaTheme.Radius.lg))
        }
        .buttonStyle(.plain)
        .disabled(isAdded)
    }
}

private struct ExtraIncomeEditCard: View {
    let template: OnboardingViewModel.ExtraTemplate
    @Binding var amountInput: String
    let currencyCode: String
    let onConfirm: () -> Void
    let onCancel: () -> Void

    @FocusState private var amountFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: SikaTheme.Spacing.md) {
            VStack(alignment: .leading, spacing: SikaTheme.Spacing.xs) {
                Text(template.name)
                    .font(SikaTheme.Typography.sans(16, weight: .semibold))
                    .foregroundStyle(SikaTheme.Color.foreground)
                Text(template.frequency.displayName)
                    .font(SikaTheme.Typography.sans(12))
                    .foregroundStyle(SikaTheme.Color.mutedForeground)
            }

            VStack(alignment: .leading, spacing: SikaTheme.Spacing.xs) {
                Text("Amount (\(CurrencyFormatter.symbol(forCode: currencyCode)))")
                    .font(SikaTheme.Typography.sans(13, weight: .semibold))
                    .foregroundStyle(SikaTheme.Color.foreground)

                HStack {
                    TextField(
                        "",
                        text: $amountInput,
                        prompt: Text("0.00").foregroundColor(SikaTheme.Color.placeholderText)
                    )
                    .font(SikaTheme.Typography.mono(15))
                    .foregroundStyle(SikaTheme.Color.foreground)
                    .keyboardType(.decimalPad)
                    .focused($amountFocused)
                    .submitLabel(.done)
                    .onSubmit { onConfirm() }
                }
                .padding(.horizontal, SikaTheme.Spacing.md)
                .frame(height: 48)
                .background(SikaTheme.Color.card)
                .overlay(
                    RoundedRectangle(cornerRadius: SikaTheme.Radius.lg)
                        .stroke(amountFocused ? SikaTheme.Color.sikaAccent : SikaTheme.Color.border,
                                lineWidth: amountFocused ? 2 : 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: SikaTheme.Radius.lg))
            }

            HStack(spacing: SikaTheme.Spacing.md) {
                Button("Cancel", action: onCancel)
                    .font(SikaTheme.Typography.sans(15, weight: .semibold))
                    .foregroundStyle(SikaTheme.Color.mutedForeground)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(SikaTheme.Color.muted)
                    .clipShape(RoundedRectangle(cornerRadius: SikaTheme.Radius.lg))

                Button("Add", action: onConfirm)
                    .font(SikaTheme.Typography.sans(15, weight: .semibold))
                    .foregroundStyle(SikaTheme.Color.primaryForeground)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(canConfirm ? SikaTheme.Color.sikaAccent : SikaTheme.Color.muted)
                    .clipShape(RoundedRectangle(cornerRadius: SikaTheme.Radius.lg))
                    .disabled(!canConfirm)
                    .opacity(canConfirm ? 1.0 : 0.6)
            }
        }
        .padding(SikaTheme.Spacing.lg)
        .background(SikaTheme.Color.card)
        .overlay(
            RoundedRectangle(cornerRadius: SikaTheme.Radius.xl)
                .stroke(SikaTheme.Color.bucketNeeds, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: SikaTheme.Radius.xl))
        .onAppear { amountFocused = true }
    }

    private var canConfirm: Bool {
        guard let value = Decimal(string: amountInput.trimmingCharacters(in: .whitespaces)) else { return false }
        return value > 0
    }
}
