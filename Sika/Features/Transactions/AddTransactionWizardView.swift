import SwiftUI

/// Multi-step wizard for Add Transaction. Owns shared state across steps.
/// Replaces the AddTransactionSheet placeholder that the FAB previously opened.
struct AddTransactionWizardView: View {
    let accounts: [Account]
    let categories: [TransactionCategory]

    @State private var viewModel = AddTransactionWizardViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showStep2NextToast = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Pinned step indicator at top
            StepIndicator3(currentStep: viewModel.currentStep.rawValue)
                .padding(.horizontal, SikaTheme.Spacing.lg)
                .padding(.top, SikaTheme.Spacing.lg)
                .padding(.bottom, SikaTheme.Spacing.md)

            // Step content (swaps based on currentStep)
            Group {
                switch viewModel.currentStep {
                case .howMuch:
                    Step1Content(viewModel: viewModel, accounts: accounts)
                case .whatFor:
                    Group {
                        if viewModel.step2IsTransferView {
                            Step2TransferView(viewModel: viewModel, accounts: accounts)
                        } else {
                            Step2CategoryGridView(viewModel: viewModel, categories: categories)
                        }
                    }
                case .anyDetails:
                    Step3PlaceholderContent()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(SikaTheme.Color.background)
        .safeAreaInset(edge: .bottom) {
            WizardBottomBar(
                viewModel: viewModel,
                accounts: accounts,
                onClose: { dismiss() },
                onStep2NextDisabled: { showStep2NextToast = true }
            )
            .padding(.horizontal, SikaTheme.Spacing.lg)
            .padding(.vertical, SikaTheme.Spacing.md)
            .background(SikaTheme.Color.background)
        }
        .overlay(alignment: .top) {
            if showStep2NextToast {
                Text("Step 3 coming soon")
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
                        withAnimation { showStep2NextToast = false }
                    }
            }
        }
    }
}

/// Bottom action bar. Step 1 shows only Next; Step 2 and 3 show Back + Next.
/// Step 2's Next is DISABLED in 1B-2b (Step 3 ships in 1B-2c).
private struct WizardBottomBar: View {
    @Bindable var viewModel: AddTransactionWizardViewModel
    let accounts: [Account]
    let onClose: () -> Void
    let onStep2NextDisabled: () -> Void

    var body: some View {
        switch viewModel.currentStep {
        case .howMuch:
            WizardNextButton(
                isEnabled: viewModel.canAdvanceFromStep1(accounts: accounts),
                action: { viewModel.goToNextStep() }
            )
        case .whatFor:
            HStack(spacing: SikaTheme.Spacing.md) {
                WizardBackButton(action: { viewModel.goToPreviousStep() })
                WizardNextButton(
                    isEnabled: false,
                    action: { onStep2NextDisabled() }
                )
            }
        case .anyDetails:
            HStack(spacing: SikaTheme.Spacing.md) {
                WizardBackButton(action: { viewModel.goToPreviousStep() })
                WizardNextButton(
                    isEnabled: false,
                    action: { /* Save in 1B-2c */ }
                )
            }
        }
    }
}

/// "Next →" pill button. Gold when enabled, muted when disabled.
private struct WizardNextButton: View {
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
    }
}

/// "← Back" muted button.
private struct WizardBackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("Back")
                .font(SikaTheme.Typography.sans(16, weight: .semibold))
                .foregroundStyle(SikaTheme.Color.foreground)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(
                    Capsule()
                        .fill(SikaTheme.Color.muted)
                )
        }
        .buttonStyle(.plain)
    }
}

/// Temporary Step 3 placeholder until 1B-2c ships.
private struct Step3PlaceholderContent: View {
    var body: some View {
        VStack(spacing: SikaTheme.Spacing.lg) {
            Spacer()
            Image(systemName: "checkmark.seal")
                .font(.system(size: 48))
                .foregroundStyle(SikaTheme.Color.sikaAccent)
            Text("Any details?")
                .font(SikaTheme.Typography.sans(28, weight: .bold))
                .foregroundStyle(SikaTheme.Color.foreground)
            Text("Coming in 1B-2c")
                .font(SikaTheme.Typography.sans(14))
                .foregroundStyle(SikaTheme.Color.mutedForeground)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, SikaTheme.Spacing.lg)
    }
}

// MARK: - Preview

#Preview("Wizard — Step 1 (Expense)") {
    AddTransactionWizardView(
        accounts: previewAccounts(),
        categories: previewCategories()
    )
}

// MARK: - PREVIEW-ONLY MOCK DATA
// ⚠️ Mock data lives ONLY in this preview block. Production code reads
// accounts and categories from appState (passed in by AuthenticatedRootView).

private func previewAccounts() -> [Account] {
    [
        previewAccount(name: "🏦 Bank", type: .general),
        previewAccount(name: "👛 Hubtel wallet", type: .wallet),
        previewAccount(name: "📱 MTN MoMo Wallet", type: .other),
        previewAccount(name: "🐷 Savings", type: .savings),
        previewAccount(name: "📱 Telecel Cash", type: .other),
        previewAccount(name: "💵 Physical Cash", type: .cash)
    ]
}

private func previewAccount(name: String, type: AccountType) -> Account {
    Account(
        id: UUID(), userId: UUID(), name: name, accountType: type,
        balance: 1000, isDefault: false, archived: false,
        createdAt: nil, updatedAt: nil
    )
}

private func previewCategories() -> [TransactionCategory] {
    [
        previewCategory(name: "🍕 Eating Out", type: .expense),
        previewCategory(name: "🛒 Groceries", type: .expense),
        previewCategory(name: "💪 Gym", type: .expense),
        previewCategory(name: "💊 Healthcare", type: .expense),
        previewCategory(name: "⚡️ Light Bill", type: .expense),
        previewCategory(name: "💼 Salary", type: .income),
        previewCategory(name: "🎁 Gift", type: .income),
    ]
}

private func previewCategory(name: String, type: CategoryType) -> TransactionCategory {
    TransactionCategory(
        id: UUID(), userId: UUID(), name: name, categoryType: type,
        bucketId: nil, archived: false, isFavorite: nil,
        createdAt: nil, updatedAt: nil
    )
}
