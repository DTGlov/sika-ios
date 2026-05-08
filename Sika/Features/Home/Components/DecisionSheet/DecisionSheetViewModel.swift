import SwiftUI
import Observation

/// State machine for the Decision Sheet.
/// 4 phases mirror web's decision-sheet.tsx Phase union.
@Observable
@MainActor
final class DecisionSheetViewModel {
    enum Phase: Equatable {
        case input
        case loading
        case result
        case error(message: String)

        var isResult: Bool {
            if case .result = self { return true }
            return false
        }
    }

    var phase: Phase = .input

    var itemName: String = ""
    var amountText: String = ""
    var bucket: PurchaseDecisionBucket = .wants
    var urgency: PurchaseUrgency? = nil

    var decisionId: UUID? = nil
    var decision: DecisionData? = nil

    /// Submission gate. Item must be non-empty; amount must parse > 0.
    /// Urgency is NOT required (matches web).
    var canSubmit: Bool {
        !itemName.trimmingCharacters(in: .whitespaces).isEmpty
            && (Double(amountText) ?? 0) > 0
    }

    /// Toggles urgency: tapping the active option deselects it.
    func toggleUrgency(_ value: PurchaseUrgency) {
        urgency = (urgency == value) ? nil : value
    }

    /// Submits the form. Transitions input → loading → result/error.
    func ask() async {
        guard canSubmit else { return }

        let request = PurchaseAnalysisRequest(
            itemName: itemName.trimmingCharacters(in: .whitespaces),
            amount: Double(amountText) ?? 0,
            bucket: bucket,
            urgency: urgency
        )

        phase = .loading

        do {
            let response = try await DecisionService.shared.ask(request)
            decisionId = response.id
            decision = response.decision
            phase = .result
        } catch {
            #if DEBUG
            print("⚠️ DecisionSheetViewModel.ask failed: \(error)")
            #endif
            phase = .error(message: "Failed to get decision. Try again.")
        }
    }

    /// Resets to the input phase. Used by the error retry button.
    func retry() {
        phase = .input
    }

    /// Records the user's outcome (best-effort). Returns true if the caller
    /// should navigate to the Transactions tab afterwards.
    func resolve(outcome: DecisionOutcome) async -> Bool {
        if let decisionId = decisionId {
            await DecisionService.shared.recordOutcome(
                decisionId: decisionId,
                outcome: outcome
            )
        }
        return outcome == .bought
    }
}
