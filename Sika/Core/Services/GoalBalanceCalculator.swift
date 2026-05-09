import Foundation

/// Pure computation of a goal's net balance from the user's transactions array.
/// Mirrors web's lib/goals.ts net pattern.
///
/// Net = sum(transactions where goal_id == goalId) - sum(transactions where paid_from_goal_id == goalId)
///
/// `goal_id` is set on transfer rows that contribute TO a goal (per Transaction.swift
/// docstring); `paid_from_goal_id` is set on expense rows paid FROM a goal's
/// accumulated savings. The filter is on the column being non-nil — type is
/// not consulted, mirroring web's predicate.
enum GoalBalanceCalculator {
    static func netBalance(goalId: UUID, transactions: [Transaction]) -> Decimal {
        var net: Decimal = 0
        for tx in transactions {
            if tx.goalId == goalId {
                net += tx.amount
            }
            if tx.paidFromGoalId == goalId {
                net -= tx.amount
            }
        }
        return net
    }
}
