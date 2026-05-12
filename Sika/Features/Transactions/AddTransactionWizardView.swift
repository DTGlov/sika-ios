import SwiftUI
import Supabase
import UIKit

/// Multi-step wizard for Add Transaction. Owns shared state across steps.
/// Replaces the AddTransactionSheet placeholder that the FAB previously opened.
///
/// T2: also serves as Edit Transaction when `editingTransaction != nil`. The
/// edit path pre-fills all wizard state, branches save → update, and skips
/// the mutation chain (no streak/momentum/badge re-ticks on edit).
struct AddTransactionWizardView: View {
    let accounts: [Account]
    let categories: [TransactionCategory]
    let editingTransaction: Transaction?
    /// Called when the user taps "Reconcile an account balance instead" on
    /// Step 1. The wizard dismisses; the parent presents the standalone
    /// reconcile sheet pre-filled with the supplied account (may be nil if
    /// no account is selected yet). Nil callback means the link shows the
    /// "Coming soon" toast (legacy behavior — unused once T3 wires the FAB
    /// path).
    let onReconcileTap: ((Account?) -> Void)?

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: AddTransactionWizardViewModel
    @State private var showSavedToast = false
    @State private var savedToastMessage = "Saved"
    @State private var showSaveErrorToast = false
    @State private var saveErrorMessage = ""

    // T3: IBS state — populated when validateBalance returns a deficit context.
    @State private var ibsContext: InsufficientBalanceContext? = nil
    /// One-shot flag the user sets via "Log anyway" so the next save attempt
    /// bypasses validateBalance and shows the warning toast on success.
    @State private var forceOverdraftSave = false

    private let transactionService = TransactionService()

    init(
        accounts: [Account],
        categories: [TransactionCategory],
        editingTransaction: Transaction? = nil,
        onReconcileTap: ((Account?) -> Void)? = nil
    ) {
        self.accounts = accounts
        self.categories = categories
        self.editingTransaction = editingTransaction
        self.onReconcileTap = onReconcileTap
        self._viewModel = State(
            initialValue: AddTransactionWizardViewModel(
                editingTransaction: editingTransaction
            )
        )
    }

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
                    Step1Content(
                        viewModel: viewModel,
                        accounts: accounts,
                        onReconcileTap: onReconcileTap.map { handler in
                            // Capture the currently-selected account at tap
                            // time. Transfer uses `selectedFromAccountId`;
                            // others use `selectedAccountId`.
                            return {
                                let pickedId = viewModel.selectedType == .transfer
                                    ? viewModel.selectedFromAccountId
                                    : viewModel.selectedAccountId
                                let picked = pickedId.flatMap { id in
                                    accounts.first { $0.id == id }
                                }
                                handler(picked)
                            }
                        }
                    )
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
                isEditMode: viewModel.isEditMode,
                onSave: { Task { await performSave() } }
            )
            .padding(.horizontal, SikaTheme.Spacing.lg)
            .padding(.vertical, SikaTheme.Spacing.md)
            .background(SikaTheme.Color.background)
        }
        .sikaToast(
            isShown: $showSavedToast,
            message: savedToastMessage,
            variant: viewModel.isEditMode ? .success : .successGreen,
            duration: viewModel.isEditMode ? .milliseconds(1200) : .milliseconds(2500)
        )
        .sikaToast(
            isShown: $showSaveErrorToast,
            message: saveErrorMessage,
            variant: .error,
            duration: .seconds(3)
        )
        .sheet(item: $ibsContext) { context in
            InsufficientBalanceSheet(
                accountName: context.accountName,
                currentBalance: context.currentBalance,
                attemptedAmount: context.attemptedAmount,
                currencyCode: appState.currencyCode,
                onCancel: {
                    // Keep wizard open; user can adjust amount or account.
                    ibsContext = nil
                },
                onReconcile: {
                    // Hand the wizard's onReconcileTap callback the
                    // debited account, then dismiss the wizard. Capture
                    // the account FIRST — `dismiss()` and the sheet-item
                    // clear race otherwise.
                    let accountId = context.accountId
                    let picked = accounts.first { $0.id == accountId }
                    ibsContext = nil
                    if let handler = onReconcileTap {
                        handler(picked)
                    }
                },
                onLogAnyway: {
                    // Bypass validateBalance on next save; performAdd
                    // surfaces the warning toast on success.
                    forceOverdraftSave = true
                    Task { await performSave() }
                }
            )
        }
    }

    // MARK: - Save flow

    private func performSave() async {
        guard let userId = appState.session?.user.id else {
            saveErrorMessage = "Not signed in"
            showSaveErrorToast = true
            return
        }

        // Medium haptic on save tap, parity with Sika save pattern across surfaces.
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        if let editing = viewModel.editingTransaction {
            await performEdit(existingId: editing.id)
            return
        }

        // T3 — insufficient-balance guard. Bypassed by `forceOverdraftSave`
        // (set by IBS's "Log anyway" action). On detection, present IBS
        // and short-circuit; the user's chosen action drives the next step.
        if !forceOverdraftSave,
           let context = viewModel.validateBalance(
               accounts: accounts,
               balances: appState.accountsBalances
           ) {
            ibsContext = context
            return
        }

        await performAdd(userId: userId)
    }

    private func performAdd(userId: UUID) async {
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

            // Phase 9: streak/momentum/badge hooks. Fire-and-forget so the
            // wizard's success animation isn't blocked. T2: also enqueues
            // the +N pts float and (when crossed) the milestone toast.
            Task {
                await appState.fireTransactionLoggedHooks()
                // T2: if this expense was paid from a target, check whether
                // the goal's fund now meets/exceeds target — awards
                // .goalCompleted (+100pts) and fires the badge trigger.
                if let goalId = saved.paidFromGoalId {
                    await appState.checkGoalCompletionFromPayment(goalId: goalId)
                }
            }

            // T2: refresh T1's list (server respects current filters — new
            // row appears at the top only if it matches).
            Task { await appState.refreshTransactionsListAfterSave() }

            viewModel.submitState = .succeeded

            savedToastMessage = toastMessage(for: viewModel.selectedType)
            showSavedToast = true

            // T3 — if the user chose "Log anyway" from IBS, surface the
            // amber warning toast 400ms after the green "Logged" toast so
            // the two don't stack. The wizard's already dismissing; the
            // warning toast is global (lives on AuthenticatedRootView).
            if forceOverdraftSave, let context = ibsContext {
                let accountName = context.accountName
                Task {
                    try? await Task.sleep(for: .milliseconds(400))
                    appState.enqueueWarningToast(
                        "Logged. Your \(accountName) is now negative."
                    )
                }
                forceOverdraftSave = false
                ibsContext = nil
            }

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

    /// Edit path. CRITICAL: never call fireTransactionLoggedHooks here —
    /// editing must not re-tick streaks/momentum/badges.
    private func performEdit(existingId: UUID) async {
        guard let payload = viewModel.buildUpdatePayload() else {
            saveErrorMessage = "Couldn't prepare update"
            showSaveErrorToast = true
            return
        }

        viewModel.submitState = .submitting

        do {
            let updated = try await transactionService.update(id: existingId, payload: payload)
            appState.replaceTransaction(updated)

            // Reflect in T1's joined list so the row updates in place.
            Task { await appState.refreshTransactionsListAfterSave() }

            viewModel.submitState = .succeeded
            savedToastMessage = "Saved"
            showSavedToast = true
            try? await Task.sleep(for: .milliseconds(800))
            dismiss()
        } catch {
            viewModel.submitState = .failed(error.localizedDescription)
            saveErrorMessage = "Couldn't save: \(error.localizedDescription)"
            showSaveErrorToast = true
            #if DEBUG
            print("⚠️ Edit transaction save failed: \(error)")
            #endif
        }
    }

    /// Type-aware toast copy. "Logged" reads naturally only for created rows;
    /// edits use a generic "Saved" — see performEdit.
    private func toastMessage(for type: TransactionType) -> String {
        switch type {
        case .expense:    return "Expense logged"
        case .income:     return "Income logged"
        case .transfer:   return "Transfer logged"
        case .adjustment: return "Adjustment logged"
        }
    }
}

/// Bottom action bar. Step 1 shows only Next; Step 2 shows Back + Next; Step 3 shows Back + Save.
private struct WizardBottomBar: View {
    @Bindable var viewModel: AddTransactionWizardViewModel
    let accounts: [Account]
    let isEditMode: Bool
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
                    label: isEditMode ? "Save" : "Add",
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

/// Save/Add gold pill button. Shows ProgressView while submitting.
private struct SaveButton: View {
    let isEnabled: Bool
    let isSubmitting: Bool
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if isSubmitting {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(SikaTheme.Color.primaryForeground)
                } else {
                    Text(label)
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
        previewAccount(name: "🏦 Bank", type: .bank),
        previewAccount(name: "👛 Hubtel wallet", type: .other),
        previewAccount(name: "📱 MTN MoMo Wallet", type: .momo),
        previewAccount(name: "🐷 Savings", type: .savings),
        previewAccount(name: "📱 Telecel Cash", type: .momo),
        previewAccount(name: "💵 Physical Cash", type: .cash)
    ]
}

private func previewAccount(name: String, type: AccountType) -> Account {
    Account(
        id: UUID(), userId: UUID(), name: name, accountType: type,
        icon: nil, color: nil, openingBalance: 1000,
        isDefault: false, isActive: true, sortOrder: 0,
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
