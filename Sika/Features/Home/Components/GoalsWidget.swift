import SwiftUI

/// Top 3 goals widget on Home. Hidden when no goals exist.
/// Each row shows the goal's net balance computed from the user's transactions
/// (sum of transfers TO the goal minus expenses paid FROM the goal). Mirrors
/// web's lib/goals.ts net pattern.
struct GoalsWidget: View {
    let goals: [Goal]
    let transactions: [Transaction]
    let currencyCode: String
    let onSeeAllTap: () -> Void

    var body: some View {
        if goals.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: SikaTheme.Spacing.sm) {
                header
                ForEach(goals) { goal in
                    GoalRow(
                        goal: goal,
                        current: GoalBalanceCalculator.netBalance(
                            goalId: goal.id,
                            transactions: transactions
                        ),
                        currencyCode: currencyCode
                    )
                }
            }
            .padding(.horizontal, SikaTheme.Spacing.lg)
        }
    }

    private var header: some View {
        HStack {
            Text("GOALS")
                .font(SikaTheme.Typography.sans(11, weight: .semibold))
                .foregroundStyle(SikaTheme.Color.mutedForeground)
                .tracking(1)
            Spacer()
            Button(action: onSeeAllTap) {
                Text("See all")
                    .font(SikaTheme.Typography.sans(13, weight: .semibold))
                    .foregroundStyle(SikaTheme.Color.sikaAccent)
            }
            .buttonStyle(.plain)
        }
    }
}

private struct GoalRow: View {
    let goal: Goal
    let current: Decimal
    let currencyCode: String

    var body: some View {
        VStack(alignment: .leading, spacing: SikaTheme.Spacing.sm) {
            HStack(spacing: SikaTheme.Spacing.md) {
                Text(IconResolver.resolve(goal.icon))
                    .font(.system(size: 18))
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(SikaTheme.Color.muted))

                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.name)
                        .font(SikaTheme.Typography.sans(15, weight: .semibold))
                        .foregroundStyle(SikaTheme.Color.foreground)

                    if goal.goalType == .perpetual {
                        Text("Perpetual")
                            .font(SikaTheme.Typography.sans(12))
                            .foregroundStyle(SikaTheme.Color.mutedForeground)
                    }
                }

                Spacer()

                Text(amountText)
                    .font(SikaTheme.Typography.mono(14, weight: .semibold))
                    .foregroundStyle(SikaTheme.Color.foreground)
            }

            if goal.goalType == .target,
               let target = goal.targetAmount, target > 0 {
                ProgressView(value: progressFraction(target: target), total: 1)
                    .tint(SikaTheme.Color.sikaAccent)
                    .scaleEffect(x: 1, y: 1.5, anchor: .center)
            }
        }
        .padding(SikaTheme.Spacing.md)
        .background(SikaTheme.Color.card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var amountText: String {
        if goal.goalType == .target, let target = goal.targetAmount {
            let currentText = CurrencyFormatter.compact(current, code: currencyCode)
            let totalText = CurrencyFormatter.compact(target, code: currencyCode)
            return "\(currentText) / \(totalText)"
        }
        return CurrencyFormatter.compact(current, code: currencyCode)
    }

    /// Progress fraction clamped to [0, 1]. Net can go negative if expenses
    /// paid from the goal exceed contributions; we floor at 0 for the bar.
    private func progressFraction(target: Decimal) -> Double {
        let currentD = Double(truncating: current as NSNumber)
        let targetD = Double(truncating: target as NSNumber)
        guard targetD > 0 else { return 0 }
        return max(0, min(1, currentD / targetD))
    }
}
