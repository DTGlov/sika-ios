import SwiftUI

struct OnboardingReviewStep: View {
    @Bindable var viewModel: OnboardingViewModel
    let onFinish: () -> Void

    private struct ReviewSource: Identifiable {
        let id: String
        let name: String
        let amount: Decimal
        let frequency: IncomeFrequency
    }

    private var reviewSources: [ReviewSource] {
        var rows: [ReviewSource] = []
        if let amount = viewModel.primaryAmount {
            rows.append(ReviewSource(
                id: "primary",
                name: viewModel.primaryName.trimmingCharacters(in: .whitespaces),
                amount: amount,
                frequency: viewModel.primaryFrequency
            ))
        }
        for s in viewModel.extraSources {
            rows.append(ReviewSource(
                id: s.id.uuidString,
                name: s.name,
                amount: s.amount,
                frequency: s.frequency
            ))
        }
        return rows
    }

    private var bucketAllocations: [(label: String, percent: Int, color: Color, amount: Decimal)] {
        let total = viewModel.totalMonthly
        return [
            ("Needs", 45, SikaTheme.Color.bucketNeeds, total * Decimal(45) / Decimal(100)),
            ("Wants", 15, SikaTheme.Color.bucketWants, total * Decimal(15) / Decimal(100)),
            ("Savings", 40, SikaTheme.Color.bucketSavings, total * Decimal(40) / Decimal(100)),
        ]
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
                Text("Your monthly income")
                    .font(SikaTheme.Typography.sans(14))
                    .foregroundStyle(SikaTheme.Color.mutedForeground)
                Text(CurrencyFormatter.format(viewModel.totalMonthly, code: viewModel.selectedCurrencyCode))
                    .font(SikaTheme.Typography.sans(32, weight: .bold))
                    .foregroundStyle(SikaTheme.Color.sikaAccent)
            }

            VStack(alignment: .leading, spacing: SikaTheme.Spacing.sm) {
                Text("Sources")
                    .font(SikaTheme.Typography.sans(13, weight: .semibold))
                    .foregroundStyle(SikaTheme.Color.foreground)
                ForEach(reviewSources) { source in
                    sourceRow(source)
                }
            }

            bucketCard
                .padding(SikaTheme.Spacing.lg)
                .background(SikaTheme.Color.card)
                .overlay(
                    RoundedRectangle(cornerRadius: SikaTheme.Radius.xl)
                        .stroke(SikaTheme.Color.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: SikaTheme.Radius.xl))

            SikaPrimaryButton(
                title: "Looks good, let's start →",
                isLoading: viewModel.isSaving,
                isEnabled: !viewModel.isSaving
            ) {
                onFinish()
            }

            if let error = viewModel.serverError {
                Text(error)
                    .font(SikaTheme.Typography.sans(13))
                    .foregroundStyle(SikaTheme.Color.destructive)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder
    private func sourceRow(_ source: ReviewSource) -> some View {
        HStack(spacing: SikaTheme.Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(source.name)
                    .font(SikaTheme.Typography.sans(14, weight: .semibold))
                    .foregroundStyle(SikaTheme.Color.foreground)
                Text(source.frequency.displayName)
                    .font(SikaTheme.Typography.sans(12))
                    .foregroundStyle(SikaTheme.Color.mutedForeground)
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 2) {
                Text(CurrencyFormatter.format(source.amount, code: viewModel.selectedCurrencyCode))
                    .font(SikaTheme.Typography.sans(14, weight: .semibold))
                    .foregroundStyle(SikaTheme.Color.foreground)
                if source.frequency != .monthly {
                    Text("≈ \(CurrencyFormatter.format(source.amount * source.frequency.monthlyMultiplier, code: viewModel.selectedCurrencyCode))/mo")
                        .font(SikaTheme.Typography.sans(11))
                        .foregroundStyle(SikaTheme.Color.mutedForeground)
                }
            }
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

    private var bucketCard: some View {
        VStack(alignment: .leading, spacing: SikaTheme.Spacing.sm) {
            Text("Sika split")
                .font(SikaTheme.Typography.sans(13, weight: .semibold))
                .foregroundStyle(SikaTheme.Color.foreground)
            Text("Sika allocates each cycle into three buckets.")
                .font(SikaTheme.Typography.sans(12))
                .foregroundStyle(SikaTheme.Color.mutedForeground)

            VStack(spacing: SikaTheme.Spacing.xs) {
                ForEach(bucketAllocations, id: \.label) { allocation in
                    bucketRow(label: allocation.label, percent: allocation.percent, color: allocation.color, amount: allocation.amount)
                }
            }
        }
    }

    @ViewBuilder
    private func bucketRow(label: String, percent: Int, color: Color, amount: Decimal) -> some View {
        HStack(spacing: SikaTheme.Spacing.sm) {
            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 10, height: 10)
                Text(label)
                    .font(SikaTheme.Typography.sans(13, weight: .semibold))
                    .foregroundStyle(SikaTheme.Color.foreground)
            }
            Text("\(percent)%")
                .font(SikaTheme.Typography.sans(12))
                .foregroundStyle(SikaTheme.Color.mutedForeground)
            Spacer(minLength: 0)
            Text(CurrencyFormatter.format(amount, code: viewModel.selectedCurrencyCode))
                .font(SikaTheme.Typography.sans(13, weight: .semibold))
                .foregroundStyle(SikaTheme.Color.foreground)
        }
    }
}
