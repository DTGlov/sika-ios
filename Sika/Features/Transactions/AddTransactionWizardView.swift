import SwiftUI
import Supabase

/// Multi-step wizard for Add Transaction. Owns shared state across steps.
/// Replaces the AddTransactionSheet placeholder that the FAB previously opened.
struct AddTransactionWizardView: View {
    let accounts: [Account]
    let categories: [TransactionCategory]

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel = AddTransactionWizardViewModel()
    @State private var showSavedToast = false
    @State private var showSaveErrorToast = false
    @State private var saveErrorMessage = ""

    private let transactionService = TransactionService()

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
                    Step3DetailsView(viewModel: viewModel)
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
                onSave: { Task { await performSave() } }
            )
            .padding(.horizontal, SikaTheme.Spacing.lg)
            .padding(.vertical, SikaTheme.Spacing.md)
            .background(SikaTheme.Color.background)
        }
        .sikaToast(
            isShown: $showSavedToast,
            message: "Saved",
            variant: .success,
            duration: .milliseconds(1200)
        )
        .sikaToast(
            isShown: $showSaveErrorToast,
            message: saveErrorMessage,
            variant: .error,
            duration: .seconds(3)
        )
    }

    // MARK: - Save flow

    private func performSave() async {
        guard let userId = appState.session?.user.id else {
            saveErrorMessage = "Not signed in"
            showSaveErrorToast = true
            return
        }

        guard let prepared = viewModel.prepareDraftAndOptimistic(userId: userId) else {
            saveErrorMessage = "Couldn't prepare transaction"
            showSaveErrorToast = true
            return
        }

        viewModel.submitState = .submitting

        // Optimistic insert into AppState — UI updates immediately
        appState.addOptimisticTransaction(prepared.optimistic)

        do {
            let saved = try await transactionService.insert(prepared.draft)
            appState.replaceOptimisticTransaction(tempId: prepared.optimistic.id, with: saved)

            // Analytics: convert domain TransactionType → AnalyticsEvent.TransactionType
            let analyticsType: AnalyticsEvent.TransactionType = {
                switch viewModel.selectedType {
                case .expense: return .expense
                case .income: return .income
                case .transfer: return .transfer
                case .adjustment: return .adjustment
                }
            }()
            AnalyticsService.shared.capture(.transactionLogged(type: analyticsType, bucket: nil))

            viewModel.submitState = .succeeded

            showSavedToast = true
            try? await Task.sleep(for: .milliseconds(800))
            dismiss()
        } catch {
            appState.removeOptimisticTransaction(tempId: prepared.optimistic.id)
            viewModel.submitState = .failed(error.localizedDescription)
            saveErrorMessage = "Couldn't save: \(error.localizedDescription)"
            showSaveErrorToast = true
            #if DEBUG
            print("⚠️ Add transaction save failed: \(error)")
            #endif
        }
    }
}

/// Bottom action bar. Step 1 shows only Next; Step 2 shows Back + Next; Step 3 shows Back + Save.
private struct WizardBottomBar: View {
    @Bindable var viewModel: AddTransactionWizardViewModel
    let accounts: [Account]
    let onSave: () -> Void

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
                    isEnabled: viewModel.canAdvanceFromStep2(),
                    action: { viewModel.goToNextStep() }
                )
            }
        case .anyDetails:
            HStack(spacing: SikaTheme.Spacing.md) {
                WizardBackButton(action: { viewModel.goToPreviousStep() })
                SaveButton(
                    isEnabled: viewModel.canSaveFromStep3(),
                    isSubmitting: viewModel.submitState == .submitting,
                    action: onSave
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
        .disabled(!isEnabled)
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

/// "Save" gold pill button. Shows ProgressView while submitting.
private struct SaveButton: View {
    let isEnabled: Bool
    let isSubmitting: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if isSubmitting {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(SikaTheme.Color.primaryForeground)
                } else {
                    Text("Save")
                        .font(SikaTheme.Typography.sans(16, weight: .semibold))
                }
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
        icon: nil, balance: 1000, isDefault: false, archived: false,
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
        bucketId: nil, icon: nil, archived: false, isFavorite: nil,
        createdAt: nil, updatedAt: nil
    )
}
