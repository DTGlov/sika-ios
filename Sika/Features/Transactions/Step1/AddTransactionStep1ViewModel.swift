import Foundation
import Observation

/// Local view model for Add Transaction Step 1 (How much?).
/// Preview-scoped; the integrated wizard in 1B-2e replaces it with the shared
/// AddTransactionViewModel that owns all 3 steps.
@Observable
@MainActor
final class AddTransactionStep1ViewModel {
    var amountString: String = ""
    var selectedType: TransactionType = .expense
    var selectedAccountId: UUID? = nil

    /// Whether Next is enabled. Requires amount > 0 AND (transfer || account selected).
    func canAdvance(accounts: [Account]) -> Bool {
        guard let amount = Decimal(string: amountString.isEmpty ? "0" : amountString),
              amount > 0 else { return false }
        if selectedType == .transfer { return true }
        return selectedAccountId != nil
    }

    /// Whether the accounts row + reconcile link should be visible.
    /// Hidden for transfer type; transfer's accounts are picked in step 2.
    var showsAccountsAndReconcile: Bool {
        selectedType != .transfer
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
}
