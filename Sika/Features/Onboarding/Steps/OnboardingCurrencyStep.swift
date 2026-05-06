import SwiftUI

struct OnboardingCurrencyStep: View {
    @Bindable var viewModel: OnboardingViewModel
    let onSkip: () -> Void

    private var currencies: [Currency] {
        CurrencyCatalog.filtered(by: viewModel.currencySearch)
    }

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
                Text("Pick your currency")
                    .font(SikaTheme.Typography.sans(22, weight: .bold))
                    .foregroundStyle(SikaTheme.Color.foreground)
                Text("All amounts will display in this currency. You can change it later in Settings.")
                    .font(SikaTheme.Typography.sans(14))
                    .foregroundStyle(SikaTheme.Color.mutedForeground)
            }

            SikaTextField(
                label: "Search",
                text: $viewModel.currencySearch,
                kind: .text,
                placeholder: "Search by code or name"
            )

            VStack(spacing: SikaTheme.Spacing.xs) {
                ForEach(currencies) { currency in
                    currencyRow(currency)
                }
            }

            VStack(spacing: SikaTheme.Spacing.sm) {
                SikaPrimaryButton(title: "Add my income") {
                    viewModel.goNext()
                }
                Button("I'll do this later", action: onSkip)
                    .font(SikaTheme.Typography.sans(14, weight: .semibold))
                    .foregroundStyle(SikaTheme.Color.mutedForeground)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
        }
    }

    @ViewBuilder
    private func currencyRow(_ currency: Currency) -> some View {
        let isSelected = currency.code == viewModel.selectedCurrencyCode
        Button {
            viewModel.selectedCurrencyCode = currency.code
        } label: {
            HStack(spacing: SikaTheme.Spacing.md) {
                Text(currency.symbol)
                    .font(SikaTheme.Typography.sans(16, weight: .semibold))
                    .foregroundStyle(isSelected ? SikaTheme.Color.sikaAccent : SikaTheme.Color.foreground)
                    .frame(width: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(currency.code)
                        .font(SikaTheme.Typography.sans(14, weight: .semibold))
                        .foregroundStyle(SikaTheme.Color.foreground)
                    Text(currency.name)
                        .font(SikaTheme.Typography.sans(12))
                        .foregroundStyle(SikaTheme.Color.mutedForeground)
                }
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(SikaTheme.Color.sikaAccent)
                }
            }
            .padding(.horizontal, SikaTheme.Spacing.md)
            .padding(.vertical, SikaTheme.Spacing.sm)
            .background(isSelected ? SikaTheme.Color.sikaAccent.opacity(0.08) : SikaTheme.Color.card)
            .overlay(
                RoundedRectangle(cornerRadius: SikaTheme.Radius.md)
                    .stroke(isSelected ? SikaTheme.Color.sikaAccent : SikaTheme.Color.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: SikaTheme.Radius.md))
        }
        .buttonStyle(.plain)
    }
}
