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

    @State private var showReconcileToast = false

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
                        ReconcileLink(onTap: { showReconcileToast = true })

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
    }
}
