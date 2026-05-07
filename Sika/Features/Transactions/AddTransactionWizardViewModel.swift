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
    var selectedGoalId: UUID? = nil  // always nil in 1B-2c; wired in 1B-2c.1

    // Submit state
    enum SubmitState: Equatable {
        case idle
        case submitting
        case succeeded
        case failed(String)
    }
    var submitState: SubmitState = .idle

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
        all.filter { $0.archived != true && $0.id != selectedToAccountId }
    }

    /// Filtered accounts for transfer To picker.
    /// Excludes archived accounts AND the From-selected account.
    func availableToAccounts(_ all: [Account]) -> [Account] {
        all.filter { $0.archived != true && $0.id != selectedFromAccountId }
    }

    // MARK: - Step 3 / Save logic

    /// Whether the Save button should be enabled. Permissive: prior steps were
    /// already validated to reach Step 3. Disable only while a submit is in flight.
    func canSaveFromStep3() -> Bool {
        submitState != .submitting
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
        let fromAccountId: UUID?
        let categoryId: UUID?
        let goalId: UUID?

        switch selectedType {
        case .expense, .income:
            guard let acc = selectedAccountId,
                  let cat = selectedCategoryId else { return nil }
            accountId = acc
            fromAccountId = nil
            categoryId = cat
            goalId = selectedGoalId  // always nil in 1B-2c
        case .transfer:
            guard let from = selectedFromAccountId,
                  let to = selectedToAccountId,
                  from != to else { return nil }
            accountId = to        // destination
            fromAccountId = from  // source
            categoryId = nil
            goalId = nil          // transfers never link to goals
        }

        let draft = TransactionDraft(
            userId: userId,
            type: selectedType,
            amount: amount,
            accountId: accountId,
            fromAccountId: fromAccountId,
            categoryId: categoryId,
            transactionDate: dateString,
            note: noteValue,
            isActive: true
        )

        let optimistic = Transaction(
            id: tempId,
            userId: userId,
            type: selectedType,
            amount: amount,
            accountId: accountId,
            fromAccountId: fromAccountId,
            categoryId: categoryId,
            goalId: goalId,
            transactionDate: dateString,
            note: noteValue,
            isActive: true,
            softDeleted: false,
            generatedFromRecurring: nil,
            createdAt: now,
            updatedAt: now
        )

        return (draft, optimistic)
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
