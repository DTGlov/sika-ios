import SwiftUI
import Supabase
import UIKit

/// Multi-step wizard for Add Transaction. Owns shared state across steps.
/// Replaces the AddTransactionSheet placeholder that the FAB previously opened.
///
/// T2: also serves as Edit Transaction when `editingTransaction != nil`. The
/// edit path pre-fills all wizard state, branches save → update, and skips
/// the mutation chain (no streak/momentum/badge re-ticks on edit).
///
/// T3 IBS redesign: the wizard handles reconcile in-place by switching its
/// own body when `appState.reconcileContext` is non-nil — no sheet dismiss
/// and re-present. IBS itself is an inline `.overlay`, not a second sheet.
/// Mirrors web's persistent-sheet-mode-swap.
struct AddTransactionWizardView: View {
    let accounts: [Account]
    let categories: [TransactionCategory]
    let editingTransaction: Transaction?

    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: AddTransactionWizardViewModel
    @State private var showSavedToast = false
    @State private var savedToastMessage = "Saved"
    @State private var showSaveErrorToast = false
    @State private var saveErrorMessage = ""

    /// IBS overlay state — populated when `validateBalance` returns a
    /// deficit context at Next-tap on Step 1 (expense) or Step 2 (transfer).
    @State private var ibsContext: InsufficientBalanceContext? = nil

    private let transactionService = TransactionService()

    init(
        accounts: [Account],
        categories: [TransactionCategory],
        editingTransaction: Transaction? = nil
    ) {
        self.accounts = accounts
        self.categories = categories
        self.editingTransaction = editingTransaction
        self._viewModel = State(
            initialValue: AddTransactionWizardViewModel(
                editingTransaction: editingTransaction
            )
        )
    }

    var body: some View {
        Group {
            if appState.reconcileContext != nil {
                reconcileModeBody
            } else {
                normalWizardBody
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(SikaTheme.Color.background)
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
        .overlay {
            if let context = ibsContext {
                InsufficientBalanceOverlay(
                    context: context,
                    currencyCode: appState.currencyCode,
                    onTopUp: { handleTopUp(context: context) },
                    onUseDifferentAccount: { handleUseDifferentAccount() },
                    onReconcile: { handleReconcileFromIBS(context: context) },
                    onCancel: { ibsContext = nil }
                )
                .zIndex(60)
            }
        }
        .animation(.easeOut(duration: 0.25), value: ibsContext)
        .onChange(of: appState.reconcileContext) { _, new in
            // IBS "Reconcile balance" or Step 1's ReconcileLink wrote to
            // appState.reconcileContext — pre-fill the wizard's reconcile
            // step. Mirrors web's pre-fill useEffect at
            // transaction-sheet.tsx:122-127.
            guard let new else { return }
            viewModel.enterReconcileMode(accountId: new.accountId)
        }
        .onDisappear {
            // Wizard fully dismissed — discard any in-flight reconcile
            // context so the next presentation doesn't inherit it.
            appState.reconcileContext = nil
        }
    }

    // MARK: - Bodies

    private var normalWizardBody: some View {
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
        .safeAreaInset(edge: .bottom) {
            WizardBottomBar(
                viewModel: viewModel,
                accounts: accounts,
                isEditMode: viewModel.isEditMode,
                onNextFromStep1: { handleNextFromStep1() },
                onNextFromStep2: { handleNextFromStep2() },
                onSave: { Task { await performSave() } }
            )
            .padding(.horizontal, SikaTheme.Spacing.lg)
            .padding(.vertical, SikaTheme.Spacing.md)
            .background(SikaTheme.Color.background)
        }
    }

    private var reconcileModeBody: some View {
        // Resolve the locked account from `appState.reconcileContext` directly
        // (not via `viewModel.selectedAccountId`) so the first render after
        // entering reconcile mode shows the correct header even before the
        // `.onChange` enterReconcileMode call lands.
        let ctx = appState.reconcileContext
        let lockedAccount = ctx
            .flatMap { c in accounts.first(where: { $0.id == c.accountId }) }
        return WizardReconcileMode(
            viewModel: viewModel,
            lockedAccount: lockedAccount,
            sikaBalance: ctx?.sikaBalance ?? 0,
            currencyCode: appState.currencyCode,
            onSave: { Task { await performReconcileSave() } }
        )
    }

    // MARK: - Next-tap interception (Step 1 / Step 2)

    /// Step 1's Next handler. Expense fires the balance check before
    /// advancing; transfer defers to Step 2's accounts-step Next.
    private func handleNextFromStep1() {
        if viewModel.selectedType == .expense,
           let context = viewModel.validateBalance(
            accounts: accounts,
            balances: appState.accountsBalances
           ) {
            ibsContext = context
            return
        }
        viewModel.goToNextStep()
    }

    /// Step 2's Next handler. Transfer fires the balance check against the
    /// From account before advancing; expense skipped (Step 1 already did).
    private func handleNextFromStep2() {
        if viewModel.selectedType == .transfer,
           let context = viewModel.validateBalance(
            accounts: accounts,
            balances: appState.accountsBalances
           ) {
            ibsContext = context
            return
        }
        viewModel.goToNextStep()
    }

    // MARK: - IBS remediation handlers

    /// Top up — swap to income mode, return to amount step. amount /
    /// accountId / note / txDate preserved (the failed N expense becomes
    /// the prefilled N income); categoryId is preserved but irrelevant.
    /// After the income commits, `performAdd` closes the wizard — the
    /// original expense draft is discarded (matches web).
    private func handleTopUp(context: InsufficientBalanceContext) {
        ibsContext = nil
        viewModel.selectedType = .income
        viewModel.currentStep = .howMuch
    }

    /// Use a different account — pure dismiss. The failing account stays
    /// selected on the chip strip; user manually re-picks. Re-fires IBS
    /// on next Next tap if the new account is also insufficient.
    private func handleUseDifferentAccount() {
        ibsContext = nil
    }

    /// Reconcile balance — write the failing context to appState; the
    /// wizard's `.onChange` handler swaps to reconcile mode in place.
    /// No sheet dismiss/re-present, no detent quirk.
    private func handleReconcileFromIBS(context: InsufficientBalanceContext) {
        ibsContext = nil
        appState.reconcileContext = ReconcileContext(
            accountId: context.accountId,
            sikaBalance: context.accountBalance
        )
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

        // IBS-redesign: balance validation runs at Next-tap (Step 1 expense,
        // Step 2 transfer) — by the time Save fires on Step 3, the check
        // has already passed. No revalidation here, no override flag.
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
            Task {
                await appState.refreshTransactionsListAfterSave()
                await appState.recomputeAccountBalances()
            }

            viewModel.submitState = .succeeded

            savedToastMessage = toastMessage(for: viewModel.selectedType)
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

    /// In-wizard reconcile commit. Inserts an adjustment row via
    /// `AppState.reconcileAccountInline` (same path as standalone reconcile
    /// from Accounts tab — adjustments do NOT fire the mutation chain).
    /// On success: clear `appState.reconcileContext`, show "Reconciled to
    /// <amount>" toast, dismiss the wizard. The original expense draft
    /// (if any) is discarded — matches web's `handleClose` after reconcile.
    private func performReconcileSave() async {
        guard let ctx = appState.reconcileContext else { return }
        guard let actual = viewModel.reconcileActualDecimal,
              viewModel.canSaveReconcile(sikaBalance: ctx.sikaBalance) else { return }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        viewModel.submitState = .submitting

        let ok = await appState.reconcileAccountInline(
            accountId: ctx.accountId,
            sikaBalance: ctx.sikaBalance,
            actualBalance: actual
        )

        if ok {
            viewModel.submitState = .succeeded
            let formatted = CurrencyFormatter.format(actual, code: appState.currencyCode)
            savedToastMessage = "Reconciled to \(formatted)"
            showSavedToast = true
            appState.reconcileContext = nil
            try? await Task.sleep(for: .milliseconds(800))
            dismiss()
        } else {
            viewModel.submitState = .failed("Failed to reconcile")
            saveErrorMessage = "Failed to reconcile"
            showSaveErrorToast = true
        }
    }
}

/// Reconcile mode body for the wizard. Account is locked (chip selector
/// hidden per web spec when entered via reconcileContext); only escape is
/// whole-sheet dismiss — no in-step Cancel button.
private struct WizardReconcileMode: View {
    @Bindable var viewModel: AddTransactionWizardViewModel
    let lockedAccount: Account?
    let sikaBalance: Decimal
    let currencyCode: String
    let onSave: () -> Void

    private var diff: Decimal? { viewModel.reconcileDiff(sikaBalance: sikaBalance) }

    private var canSave: Bool { viewModel.canSaveReconcile(sikaBalance: sikaBalance) }

    var body: some View {
        VStack(alignment: .leading, spacing: SikaTheme.Spacing.lg) {
            Text("Reconcile balance")
                .font(SikaTheme.Typography.sans(28, weight: .bold))
                .foregroundStyle(SikaTheme.Color.foreground)
                .padding(.horizontal, SikaTheme.Spacing.lg)
                .padding(.top, SikaTheme.Spacing.lg)

            ScrollView {
                VStack(alignment: .leading, spacing: SikaTheme.Spacing.lg) {
                    if let acc = lockedAccount { accountHeader(acc) }
                    sikaBalanceRow
                    actualField
                    if viewModel.reconcileActualDecimal != nil {
                        diffCard
                    }
                    Spacer().frame(height: SikaTheme.Spacing.lg)
                }
                .padding(.horizontal, SikaTheme.Spacing.lg)
                .padding(.top, SikaTheme.Spacing.sm)
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollIndicators(.hidden)
        }
        .safeAreaInset(edge: .bottom) {
            reconcileSaveButton
                .padding(.horizontal, SikaTheme.Spacing.lg)
                .padding(.vertical, SikaTheme.Spacing.md)
                .background(SikaTheme.Color.background)
        }
    }

    private func accountHeader(_ account: Account) -> some View {
        let cfg = AccountTypeConfigs.config(for: account.accountType)
        return HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(cfg.color.opacity(0.094))
                    .frame(width: 44, height: 44)
                Text(cfg.emoji)
                    .font(.system(size: 22))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(account.name)
                    .font(SikaTheme.Typography.sans(16, weight: .bold))
                    .foregroundStyle(SikaTheme.Color.foreground)
                Text(cfg.label)
                    .font(SikaTheme.Typography.sans(11))
                    .foregroundStyle(SikaTheme.Color.mutedForeground)
            }
            Spacer()
        }
    }

    private var sikaBalanceRow: some View {
        HStack {
            Text("Sika shows")
                .font(SikaTheme.Typography.sans(13))
                .foregroundStyle(SikaTheme.Color.mutedForeground)
            Spacer()
            Text(CurrencyFormatter.format(sikaBalance, code: currencyCode))
                .font(SikaTheme.Typography.sans(15, weight: .semibold))
                .foregroundStyle(SikaTheme.Color.foreground)
                .monospacedDigit()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(SikaTheme.Color.muted)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var actualField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Actual current balance")
                .font(SikaTheme.Typography.sans(12, weight: .semibold))
                .foregroundStyle(SikaTheme.Color.foreground)
            HStack(spacing: 6) {
                Text(CurrencyFormatter.symbol(forCode: currencyCode))
                    .font(SikaTheme.Typography.sans(13))
                    .foregroundStyle(SikaTheme.Color.mutedForeground)
                TextField("0.00", text: $viewModel.reconcileActualString)
                    .keyboardType(.decimalPad)
                    .font(SikaTheme.Typography.sans(15, weight: .semibold))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(SikaTheme.Color.card)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(SikaTheme.Color.border, lineWidth: 1)
            )
        }
    }

    private var diffCard: some View {
        let value = diff ?? 0
        let isPositive = value >= 0
        let color = isPositive ? Color(hex: 0x00D9A3) : Color(hex: 0xF43F5E)
        let absDiff: Decimal = isPositive ? value : -value
        let sign = isPositive ? "+" : "−"

        return HStack {
            Text("Adjustment")
                .font(SikaTheme.Typography.sans(12, weight: .semibold))
                .foregroundStyle(color)
            Spacer()
            Text("\(sign)\(CurrencyFormatter.format(absDiff, code: currencyCode))")
                .font(SikaTheme.Typography.sans(13, weight: .bold))
                .foregroundStyle(color)
                .monospacedDigit()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(color.opacity(0.094))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var reconcileSaveButton: some View {
        Button(action: onSave) {
            HStack {
                if viewModel.submitState == .submitting {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(SikaTheme.Color.primaryForeground)
                } else {
                    Text("Create adjustment")
                        .font(SikaTheme.Typography.sans(16, weight: .semibold))
                }
            }
            .foregroundStyle(canSave
                ? SikaTheme.Color.primaryForeground
                : SikaTheme.Color.mutedForeground)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(
                Capsule()
                    .fill(canSave
                        ? SikaTheme.Color.sikaAccent
                        : SikaTheme.Color.muted)
            )
        }
        .buttonStyle(.plain)
        .disabled(!canSave)
    }
}

/// Bottom action bar. Step 1 shows only Next; Step 2 shows Back + Next; Step 3 shows Back + Save.
/// Next-tap callbacks route through the parent wizard so the parent can run
/// the balance check before advancing the step (Step 1 for expense, Step 2
/// for transfer).
private struct WizardBottomBar: View {
    @Bindable var viewModel: AddTransactionWizardViewModel
    let accounts: [Account]
    let isEditMode: Bool
    let onNextFromStep1: () -> Void
    let onNextFromStep2: () -> Void
    let onSave: () -> Void

    var body: some View {
        switch viewModel.currentStep {
        case .howMuch:
            WizardNextButton(
                isEnabled: viewModel.canAdvanceFromStep1(accounts: accounts),
                action: onNextFromStep1
            )
        case .whatFor:
            HStack(spacing: SikaTheme.Spacing.md) {
                WizardBackButton(action: { viewModel.goToPreviousStep() })
                WizardNextButton(
                    isEnabled: viewModel.canAdvanceFromStep2(),
                    action: onNextFromStep2
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
