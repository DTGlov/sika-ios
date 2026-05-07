import SwiftUI

/// Top 3 goals widget on Home. Hidden when no goals exist.
/// Goal progress (current saved amount) ships in Phase 2.1; this widget
/// renders progress bars at 0% for target goals.
struct GoalsWidget: View {
    let goals: [Goal]
    let currencyCode: String
    let onSeeAllTap: () -> Void

    var body: some View {
        if goals.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: SikaTheme.Spacing.sm) {
                header
                ForEach(goals) { goal in
                    GoalRow(goal: goal, currencyCode: currencyCode)
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

            // Progress bar (target only). Phase 2 hardcodes progress=0 because
            // computing contributions per goal needs a dedicated aggregation
            // (transactions where goalId == goal.id summed). Phase 2.1 follow-up.
            if goal.goalType == .target,
               let target = goal.targetAmount, target > 0 {
                ProgressView(value: 0, total: 1)
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
            // Phase 2: current is 0 (progress derivation deferred to Phase 2.1).
            let current = CurrencyFormatter.compact(0, code: currencyCode)
            let total = CurrencyFormatter.compact(target, code: currencyCode)
            return "\(current) / \(total)"
        }
        // Perpetual: no target — show 0 placeholder until contributions land.
        return CurrencyFormatter.compact(0, code: currencyCode)
    }
}
