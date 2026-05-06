//
//  AddTransactionStep1View.swift
//  Sika
//
//  Step 1 of the Add Transaction wizard: "How much?"
//
//  ⚠️ INTEGRATION CONTRACT (1B-2e):
//  The `accounts` parameter MUST be fed from appState.accounts.
//  Do NOT hardcode account data when integrating into the wizard.
//  Mock data exists ONLY in the SwiftUI preview blocks below.
//
//  The cedi sign (₵, U+20B5) display, the type-conditional layout
//  (transfer hides accounts/reconcile), and the teal selection palette
//  for accounts are locked design decisions matching web mobile parity.
//

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
        .padding(.top, SikaTheme.Spacing.lg)
        .padding(.bottom, SikaTheme.Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(SikaTheme.Color.background)
        .ignoresSafeArea(.keyboard)
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
    PreviewSheetWrapper {
        AddTransactionStep1View(accounts: previewMockAccounts())
    }
}

#Preview("Step 1 — transfer mode") {
    PreviewSheetWrapper {
        AddTransactionStep1View(accounts: [
            previewMockAccount(name: "Bank", type: .general),
            previewMockAccount(name: "Savings", type: .savings),
        ])
    }
}

/// Wrapper that simulates sheet presentation in the preview canvas so we
/// see the view with proper safe-area handling, matching how it'll render
/// when integrated into a real .sheet() in 1B-2e.
private struct PreviewSheetWrapper<Content: View>: View {
    @ViewBuilder let content: () -> Content
    @State private var isShown = true

    var body: some View {
        Color.black.opacity(0.05)
            .ignoresSafeArea()
            .sheet(isPresented: $isShown) {
                content()
            }
    }
}

// MARK: - PREVIEW-ONLY MOCK DATA
// ⚠️ These mocks are ONLY for SwiftUI previews. When this view is integrated into
// the wizard in 1B-2e, accounts MUST come from appState.accounts — never hardcoded.
// The names below match Dave's real accounts coincidentally for visual fidelity in
// the preview, but they're still mock UUIDs and will not match production data.

private func previewMockAccounts() -> [Account] {
    [
        previewMockAccount(name: "Bank", type: .general),
        previewMockAccount(name: "Hubtel wallet", type: .wallet),
        previewMockAccount(name: "MTN MoMo Wallet", type: .other),
        previewMockAccount(name: "Savings", type: .savings),
        previewMockAccount(name: "Telecel Cash", type: .other),
        previewMockAccount(name: "Physical Cash", type: .cash)
    ]
}

private func previewMockAccount(name: String, type: AccountType) -> Account {
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
