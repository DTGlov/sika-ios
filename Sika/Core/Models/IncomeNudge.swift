import Foundation

/// In-memory wrapper. NOT a database table.
/// Synthesized from an IncomeSource + today's date by IncomeNudgeService.
struct IncomeNudge: Identifiable, Equatable {
    let incomeSource: IncomeSource
    let dueDate: String   // YYYY-MM-DD

    var id: UUID { incomeSource.id }
}

/// User's response to an income nudge. Mirrors income_nudge_dismissals.action.
/// All three actions suppress the card equally — `action` is metadata only.
enum IncomeNudgeAction: String, Codable {
    case logged, snoozed, dismissed
}
