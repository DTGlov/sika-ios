import SwiftUI

/// Add Transaction — Step 1: "How much?"
/// Standalone preview-only in 1B-2a. Will be integrated into the wizard in 1B-2e.
struct AddTransactionStep1View: View {
    let accounts: [Account]

    @State private var viewModel = AddTransactionStep1ViewModel()
    @State private var showReconcileToast = false

    private var bindingForType: Binding<TransactionType> {
        Binding(get: { viewModel.selectedType }, set: { viewModel.selectedType = $0 })
    }
    private var bindingForAccountId: Binding<UUID?> {
        Binding(get: { viewModel.selectedAccountId }, set: { viewModel.selectedAccountId = $0 })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SikaTheme.Spacing.lg) {
            Text("How much?")
                .font(SikaTheme.Typography.sans(28, weight: .bold))
                .foregroundStyle(SikaTheme.Color.foreground)

            StepIndicator3(currentStep: 1)

            Spacer().frame(height: SikaTheme.Spacing.lg)

            VStack(spacing: SikaTheme.Spacing.lg) {
                AmountDisplay(amountString: viewModel.amountString)
                TypePillSelector(selected: bindingForType)
            }
            .frame(maxWidth: .infinity)

            NumberPad(
                onDigitTap: { viewModel.appendDigit($0) },
                onBackspaceTap: { viewModel.backspace() }
            )

            if viewModel.showsAccountsAndReconcile {
                ReconcileLink(onTap: { showReconcileToast = true })

                AccountChipsRow(
                    accounts: accounts,
                    selectedId: bindingForAccountId
                )
            }

            Spacer()

            NextButton(
                isEnabled: viewModel.canAdvance(accounts: accounts),
                action: {
                    // Wizard navigation lands in 1B-2e
                }
            )
        }
        .padding(.horizontal, SikaTheme.Spacing.lg)
        .padding(.vertical, SikaTheme.Spacing.lg)
        .background(SikaTheme.Color.background)
        .overlay(alignment: .top) {
            if showReconcileToast {
                Text("Reconcile coming soon")
                    .font(SikaTheme.Typography.sans(14, weight: .semibold))
                    .foregroundStyle(SikaTheme.Color.foreground)
                    .padding(.horizontal, SikaTheme.Spacing.md)
                    .padding(.vertical, SikaTheme.Spacing.sm)
                    .background(SikaTheme.Color.card)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                    .padding(.top, SikaTheme.Spacing.lg)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task {
                        try? await Task.sleep(for: .seconds(2))
                        withAnimation { showReconcileToast = false }
                    }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85),
                   value: viewModel.showsAccountsAndReconcile)
    }
}

/// Sticky Next button at the bottom of step 1.
private struct NextButton: View {
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: SikaTheme.Spacing.xs) {
                Text("Next")
                    .font(SikaTheme.Typography.sans(16, weight: .semibold))
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(isEnabled
                ? SikaTheme.Color.primaryForeground
                : SikaTheme.Color.mutedForeground)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(
                Capsule()
                    .fill(isEnabled
                        ? SikaTheme.Color.sikaAccent
                        : SikaTheme.Color.muted)
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

// MARK: - Preview

#Preview("Step 1 — empty") {
    AddTransactionStep1View(accounts: [
        previewAccount(name: "Bank", type: .general),
        previewAccount(name: "Hubtel wallet", type: .wallet),
        previewAccount(name: "MTN MoMo Wallet", type: .other),
        previewAccount(name: "Savings", type: .savings),
        previewAccount(name: "Telecel Cash", type: .other),
        previewAccount(name: "Physical Cash", type: .cash)
    ])
}

#Preview("Step 1 — transfer mode") {
    AddTransactionStep1View(accounts: [
        previewAccount(name: "Bank", type: .general),
        previewAccount(name: "Savings", type: .savings),
    ])
}

private func previewAccount(name: String, type: AccountType) -> Account {
    Account(
        id: UUID(),
        userId: UUID(),
        name: name,
        accountType: type,
        balance: 0,
        isDefault: false,
        archived: false,
        createdAt: nil,
        updatedAt: nil
    )
}
