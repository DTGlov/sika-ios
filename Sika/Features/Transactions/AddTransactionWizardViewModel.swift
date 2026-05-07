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

    // Step 3 fields (placeholders for 1B-2c)
    var note: String = ""
    var transactionDate: Date = Date()

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
