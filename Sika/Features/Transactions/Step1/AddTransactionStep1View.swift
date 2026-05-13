//
//  Step1Content.swift (file path retained as AddTransactionStep1View.swift)
//  Sika
//
//  Step 1 content of the Add Transaction wizard.
//  The wizard shell (AddTransactionWizardView) renders the step indicator
//  and Back/Next bar; this view renders only step 1's heading + amount
//  + type pills + numpad + reconcile + accounts.
//
//  ⚠️ This view binds to AddTransactionWizardViewModel via @Bindable.
//  It does not manage its own form state.
//

import SwiftUI

struct Step1Content: View {
    @Bindable var viewModel: AddTransactionWizardViewModel
    let accounts: [Account]

    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: SikaTheme.Spacing.lg) {
            // PINNED TOP REGION (within the step): heading + amount + type pills
            VStack(alignment: .leading, spacing: SikaTheme.Spacing.lg) {
                Text("How much?")
                    .font(SikaTheme.Typography.sans(28, weight: .bold))
                    .foregroundStyle(SikaTheme.Color.foreground)

                VStack(spacing: SikaTheme.Spacing.lg) {
                    AmountDisplay(amountString: viewModel.amountString)
                    TypePillSelector(selected: $viewModel.selectedType)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, SikaTheme.Spacing.md)
            }
            .padding(.horizontal, SikaTheme.Spacing.lg)

            // SCROLLABLE MIDDLE: numpad + reconcile + accounts
            ScrollView {
                VStack(spacing: SikaTheme.Spacing.lg) {
                    NumberPad(
                        onDigitTap: { viewModel.appendDigit($0) },
                        onBackspaceTap: { viewModel.backspace() }
                    )

                    if viewModel.step1ShowsAccountsAndReconcile {
                        ReconcileLink(onTap: handleReconcileTap)

                        AccountChipsRow(
                            accounts: accounts,
                            selectedId: $viewModel.selectedAccountId
                        )
                    }

                    Spacer().frame(height: SikaTheme.Spacing.lg)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, SikaTheme.Spacing.lg)
                .padding(.top, SikaTheme.Spacing.md)
                .animation(.spring(response: 0.4, dampingFraction: 0.85),
                           value: viewModel.step1ShowsAccountsAndReconcile)
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollIndicators(.hidden)
        }
    }

    /// ReconcileLink shortcut — writes the currently-picked account (or the
    /// first active account as fallback) into `appState.reconcileContext`.
    /// The wizard's `.onChange` handler swaps to reconcile mode in place;
    /// no sheet dismiss/re-present.
    private func handleReconcileTap() {
        let pickedId = viewModel.selectedType == .transfer
            ? viewModel.selectedFromAccountId
            : viewModel.selectedAccountId

        let target: Account? = pickedId
            .flatMap { id in accounts.first(where: { $0.id == id }) }
            ?? accounts.first(where: { $0.isActive != false })

        guard let acc = target else { return }

        let balance = AccountBalanceEngine.balance(
            for: acc,
            in: appState.accountsBalances
        )
        appState.reconcileContext = ReconcileContext(
            accountId: acc.id,
            sikaBalance: balance
        )
    }
}
