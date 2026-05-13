import Foundation
import SwiftUI
import Observation

/// Shared view model spanning all 3 steps of Add Transaction.
/// Each step view binds to fields here; the wizard shell observes step
/// transitions and form completeness.
@Observable
@MainActor
final class AddTransactionWizardViewModel {
    enum Step: Int, CaseIterable {
        case howMuch = 1
        case whatFor = 2
        case anyDetails = 3
    }

    /// Set when the wizard is opened in edit mode. Pre-fills all fields and
    /// branches performSave to the update path (which skips mutation hooks).
    let editingTransaction: Transaction?

    var isEditMode: Bool { editingTransaction != nil }

    // Navigation
    var currentStep: Step = .howMuch

    // Step 1 fields
    var amountString: String = ""
    var selectedType: TransactionType = .expense
    var selectedAccountId: UUID? = nil

    // Step 2 fields
    var selectedCategoryId: UUID? = nil
    var selectedFromAccountId: UUID? = nil
    var selectedToAccountId: UUID? = nil

    // Step 3 fields
    var note: String = ""
    var transactionDate: Date = Date()
    var selectedGoalId: UUID? = nil  // wired in T2

    /// Actual-balance keypad input for the in-wizard reconcile step
    /// (entered via IBS "Reconcile balance" or Step 1's ReconcileLink).
    /// Empty until the user types; cleared whenever reconcile mode is
    /// entered fresh.
    var reconcileActualString: String = ""

    // Submit state
    enum SubmitState: Equatable {
        case idle
        case submitting
        case succeeded
        case failed(String)
    }
    var submitState: SubmitState = .idle

    init(editingTransaction: Transaction? = nil) {
        self.editingTransaction = editingTransaction
        guard let txn = editingTransaction else { return }

        // Pre-fill state from the existing row.
        self.selectedType = txn.type
        self.amountString = Self.formatAmountForKeypad(txn.amount)
        switch txn.type {
        case .transfer:
            self.selectedFromAccountId = txn.accountId
            self.selectedToAccountId = txn.toAccountId
        case .expense, .income, .adjustment:
            self.selectedAccountId = txn.accountId
        }
        self.selectedCategoryId = txn.categoryId
        self.note = txn.note ?? ""
        if let parsed = Self.parseTransactionDate(txn.transactionDate) {
            self.transactionDate = parsed
        }
        self.selectedGoalId = txn.paidFromGoalId
    }

    /// Convert a decimal amount into the keypad string. Drops trailing
    /// ".00" so e.g. `50` displays as "50" not "50.00".
    private static func formatAmountForKeypad(_ amount: Decimal) -> String {
        let ns = NSDecimalNumber(decimal: amount)
        if ns.doubleValue.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(ns.intValue)"
        }
        return "\(ns.doubleValue)"
    }

    private static func parseTransactionDate(_ str: String) -> Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        return f.date(from: str)
    }

    // MARK: - Step 1 logic

    /// Whether step 1's accounts row + reconcile link should be visible.
    /// Hidden for transfer (transfer's accounts are picked in step 2).
    var step1ShowsAccountsAndReconcile: Bool {
        selectedType != .transfer
    }

    /// Step 1 → Step 2 readiness.
    func canAdvanceFromStep1(accounts: [Account]) -> Bool {
        guard let amount = Decimal(string: amountString.isEmpty ? "0" : amountString),
              amount > 0 else { return false }
        if selectedType == .transfer { return true }
        return selectedAccountId != nil
    }

    func appendDigit(_ digit: String) {
        if digit == "." && amountString.contains(".") { return }
        if amountString == "0" && digit != "." { amountString = "" }
        amountString.append(digit)
    }

    func backspace() {
        guard !amountString.isEmpty else { return }
        amountString.removeLast()
    }

    // MARK: - Step 2 logic

    /// Whether the transfer-style Step 2 view should be shown.
    var step2IsTransferView: Bool {
        selectedType == .transfer
    }

    /// Step 2 → Step 3 readiness.
    func canAdvanceFromStep2() -> Bool {
        if selectedType == .transfer {
            guard let from = selectedFromAccountId,
                  let to = selectedToAccountId,
                  from != to else { return false }
            return true
        }
        return selectedCategoryId != nil
    }

    /// Filtered categories for Step 2 grid.
    /// Filter by transaction type and archive state. Sort favorites first,
    /// then alphabetical case-insensitive.
    func availableCategories(_ all: [TransactionCategory]) -> [TransactionCategory] {
        let categoryType: CategoryType = (selectedType == .income) ? .income : .expense
        return all
            .filter { $0.categoryType == categoryType }
            .filter { $0.archived != true }
            .sorted { lhs, rhs in
                let lhsFav = lhs.isFavorite ?? false
                let rhsFav = rhs.isFavorite ?? false
                if lhsFav != rhsFav { return lhsFav }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    /// Filtered accounts for transfer From picker.
    /// Excludes archived accounts AND the To-selected account.
    func availableFromAccounts(_ all: [Account]) -> [Account] {
        all.filter { $0.isActive != false && $0.id != selectedToAccountId }
    }

    /// Filtered accounts for transfer To picker.
    /// Excludes archived accounts AND the From-selected account.
    func availableToAccounts(_ all: [Account]) -> [Account] {
        all.filter { $0.isActive != false && $0.id != selectedFromAccountId }
    }

    // MARK: - Step 3 / Save logic

    /// Whether the Save button should be enabled. Permissive: prior steps were
    /// already validated to reach Step 3. Disable only while a submit is in flight.
    func canSaveFromStep3() -> Bool {
        submitState != .submitting
    }

    /// T3 — insufficient-balance check. Returns the context for the IBS
    /// when the save would take the debited account negative; nil when
    /// the save is safe. Income skips the check (no debit). Edit mode
    /// also skips — the original row's amount already moved the balance,
    /// so an edit isn't a fresh debit; reapplying the guard would block
    /// legitimate corrections.
    func validateBalance(
        accounts: [Account],
        balances: [UUID: Decimal]
    ) -> InsufficientBalanceContext? {
        guard !isEditMode else { return nil }

        guard let amount = Decimal(string: amountString.isEmpty ? "0" : amountString),
              amount > 0 else { return nil }

        let debitAccountId: UUID?
        switch selectedType {
        case .expense:
            debitAccountId = selectedAccountId
        case .transfer:
            debitAccountId = selectedFromAccountId
        case .income, .adjustment:
            return nil
        }

        guard let accountId = debitAccountId,
              let account = accounts.first(where: { $0.id == accountId }) else {
            return nil
        }

        let current = AccountBalanceEngine.balance(for: account, in: balances)
        guard amount > current else { return nil }

        return InsufficientBalanceContext(
            accountId: accountId,
            accountName: account.name,
            accountBalance: current,
            amountRequested: amount
        )
    }

    /// Enter in-wizard reconcile mode. Called from the wizard's
    /// `.onChange(of: appState.reconcileContext)` when a non-nil context
    /// arrives (IBS "Reconcile balance" or Step 1's ReconcileLink shortcut).
    /// Mirrors web's pre-fill `useEffect` at transaction-sheet.tsx:122-127.
    func enterReconcileMode(accountId: UUID) {
        selectedType = .adjustment
        selectedAccountId = accountId
        reconcileActualString = ""
        note = ""
    }

    /// Parse the reconcile keypad input into a Decimal. Empty / unparseable
    /// returns nil so the Save button stays disabled.
    var reconcileActualDecimal: Decimal? {
        let trimmed = reconcileActualString.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        return Decimal(string: trimmed)
    }

    /// Signed diff for the in-wizard reconcile step: `actual - sika`.
    /// Returns nil when no actual is entered yet.
    func reconcileDiff(sikaBalance: Decimal) -> Decimal? {
        guard let actual = reconcileActualDecimal else { return nil }
        return actual - sikaBalance
    }

    /// Whether the wizard's reconcile Save button is tappable. Mirrors
    /// `canSubmit` from the standalone `ReconcileAccountSheet`: non-empty
    /// input, parseable, non-zero diff, not currently submitting.
    func canSaveReconcile(sikaBalance: Decimal) -> Bool {
        guard submitState != .submitting,
              let diff = reconcileDiff(sikaBalance: sikaBalance) else { return false }
        return diff != 0
    }

    /// Build both the insert payload (TransactionDraft) and the optimistic local
    /// row (Transaction) from the wizard's accumulated state. Returns nil if
    /// validation fails defensively (shouldn't happen if Step 3 was reached
    /// legitimately).
    func prepareDraftAndOptimistic(userId: UUID) -> (draft: TransactionDraft, optimistic: Transaction)? {
        guard let amount = Decimal(string: amountString.isEmpty ? "0" : amountString),
              amount > 0 else { return nil }

        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let noteValue: String? = trimmedNote.isEmpty ? nil : trimmedNote
        let dateString = Self.formatTransactionDate(transactionDate)
        let now = Date()
        let tempId = UUID()

        let accountId: UUID
        let toAccountId: UUID?
        let categoryId: UUID?
        let goalId: UUID?

        let paidFromGoalId: UUID?
        switch selectedType {
        case .expense:
            guard let acc = selectedAccountId,
                  let cat = selectedCategoryId else { return nil }
            accountId = acc
            toAccountId = nil
            categoryId = cat
            goalId = nil
            // Only expenses can be "paid from a target" — income/transfer
            // routes don't surface the picker.
            paidFromGoalId = selectedGoalId
        case .income:
            guard let acc = selectedAccountId,
                  let cat = selectedCategoryId else { return nil }
            accountId = acc
            toAccountId = nil
            categoryId = cat
            goalId = nil
            paidFromGoalId = nil
        case .transfer:
            guard let from = selectedFromAccountId,
                  let to = selectedToAccountId,
                  from != to else { return nil }
            // Web's convention: account_id is the source/FROM, to_account_id
            // is the destination/TO. Display is "account → toAccount".
            accountId = from      // source
            toAccountId = to      // destination
            categoryId = nil
            goalId = nil          // transfers never link to goals
            paidFromGoalId = nil
        case .adjustment:
            // Not creatable from the wizard — only web's Reconcile flow
            // produces adjustment rows. Bail defensively if reached.
            return nil
        }

        let draft = TransactionDraft(
            userId: userId,
            type: selectedType,
            amount: amount,
            accountId: accountId,
            toAccountId: toAccountId,
            categoryId: categoryId,
            transactionDate: dateString,
            note: noteValue,
            paidFromGoalId: paidFromGoalId
        )

        let optimistic = Transaction(
            id: tempId,
            userId: userId,
            type: selectedType,
            amount: amount,
            accountId: accountId,
            toAccountId: toAccountId,
            categoryId: categoryId,
            goalId: goalId,
            paidFromGoalId: paidFromGoalId,
            transactionDate: dateString,
            note: noteValue,
            softDeleted: false,
            generatedFromRecurring: nil,
            createdAt: now,
            updatedAt: now
        )

        return (draft, optimistic)
    }

    /// Build the update payload for the T2 edit path. Returns nil if the
    /// current state isn't a valid transaction (shouldn't happen if Step 3
    /// reached this point legitimately).
    func buildUpdatePayload() -> TransactionUpdate? {
        guard let amount = Decimal(string: amountString.isEmpty ? "0" : amountString),
              amount > 0 else { return nil }

        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let noteValue: String? = trimmedNote.isEmpty ? nil : trimmedNote
        let dateString = Self.formatTransactionDate(transactionDate)

        let accountId: UUID
        let toAccountId: UUID?
        let categoryId: UUID?
        let paidFromGoalId: UUID?

        switch selectedType {
        case .expense:
            guard let acc = selectedAccountId,
                  let cat = selectedCategoryId else { return nil }
            accountId = acc; toAccountId = nil; categoryId = cat
            paidFromGoalId = selectedGoalId
        case .income:
            guard let acc = selectedAccountId,
                  let cat = selectedCategoryId else { return nil }
            accountId = acc; toAccountId = nil; categoryId = cat
            paidFromGoalId = nil
        case .transfer:
            guard let from = selectedFromAccountId,
                  let to = selectedToAccountId,
                  from != to else { return nil }
            accountId = from; toAccountId = to; categoryId = nil
            paidFromGoalId = nil
        case .adjustment:
            return nil
        }

        return TransactionUpdate(
            type: selectedType,
            amount: amount,
            accountId: accountId,
            toAccountId: toAccountId,
            categoryId: categoryId,
            transactionDate: dateString,
            note: noteValue,
            paidFromGoalId: paidFromGoalId
        )
    }

    private static func formatTransactionDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        return f.string(from: date)
    }

    // MARK: - Navigation

    func goToNextStep() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            switch currentStep {
            case .howMuch: currentStep = .whatFor
            case .whatFor: currentStep = .anyDetails
            case .anyDetails: break
            }
        }
    }

    func goToPreviousStep() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            switch currentStep {
            case .howMuch: break
            case .whatFor: currentStep = .howMuch
            case .anyDetails: currentStep = .whatFor
            }
        }
    }
}
