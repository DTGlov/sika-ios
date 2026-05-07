import SwiftUI

/// Step 2 content for transfers: From and To account selection.
struct Step2TransferView: View {
    @Bindable var viewModel: AddTransactionWizardViewModel
    let accounts: [Account]

    var body: some View {
        VStack(alignment: .leading, spacing: SikaTheme.Spacing.lg) {
            Text("Transfer between")
                .font(SikaTheme.Typography.sans(28, weight: .bold))
                .foregroundStyle(SikaTheme.Color.foreground)
                .padding(.horizontal, SikaTheme.Spacing.lg)

            ScrollView {
                VStack(alignment: .leading, spacing: SikaTheme.Spacing.lg) {
                    // FROM
                    VStack(alignment: .leading, spacing: SikaTheme.Spacing.sm) {
                        Text("From")
                            .font(SikaTheme.Typography.sans(13))
                            .foregroundStyle(SikaTheme.Color.mutedForeground)

                        AccountChipsRow(
                            accounts: viewModel.availableFromAccounts(accounts),
                            selectedId: $viewModel.selectedFromAccountId,
                            selectionTint: SikaTheme.Color.bucketNeeds,
                            showLabel: false
                        )
                    }

                    // Arrow divider
                    HStack(spacing: SikaTheme.Spacing.sm) {
                        Rectangle()
                            .fill(SikaTheme.Color.border)
                            .frame(height: 1)
                        Image(systemName: "arrow.right")
                            .foregroundStyle(SikaTheme.Color.mutedForeground)
                            .font(.system(size: 14))
                        Rectangle()
                            .fill(SikaTheme.Color.border)
                            .frame(height: 1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, SikaTheme.Spacing.sm)

                    // TO
                    VStack(alignment: .leading, spacing: SikaTheme.Spacing.sm) {
                        Text("To")
                            .font(SikaTheme.Typography.sans(13))
                            .foregroundStyle(SikaTheme.Color.mutedForeground)

                        AccountChipsRow(
                            accounts: viewModel.availableToAccounts(accounts),
                            selectedId: $viewModel.selectedToAccountId,
                            selectionTint: SikaTheme.Color.sikaAccent,
                            showLabel: false
                        )
                    }

                    Spacer().frame(height: SikaTheme.Spacing.lg)
                }
                .padding(.horizontal, SikaTheme.Spacing.lg)
                .padding(.top, SikaTheme.Spacing.sm)
            }
            .scrollIndicators(.hidden)
        }
    }
}
