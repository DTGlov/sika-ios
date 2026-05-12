import SwiftUI

/// Sheet for choosing a target goal to flag this expense as "paid from".
/// Lists active target goals (goalType=.target, completedAt nil, not archived).
/// Replaces the EmptyTargetsSheet stub from the pre-T2 wizard.
struct TargetGoalPicker: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @Binding var selectedGoalId: UUID?

    private var availableGoals: [Goal] {
        // Source of truth: appState.goals (the simple array hydrated at
        // profile load). Falls back to goalsList when the simple array
        // is empty (e.g. user opened Goals T1 before the Home goals
        // hydration pass on a slow network).
        let source = appState.goals.isEmpty ? appState.goalsList : appState.goals
        return source.filter { goal in
            goal.goalType == .target &&
            goal.completedAt == nil &&
            goal.isArchived != true
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    noneRow
                }

                if availableGoals.isEmpty {
                    Section {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("No active target goals.")
                                .font(SikaTheme.Typography.sans(14, weight: .semibold))
                                .foregroundStyle(SikaTheme.Color.foreground)
                            Text("Create a savings target in the Goals tab to flag payments against it here.")
                                .font(SikaTheme.Typography.sans(12))
                                .foregroundStyle(SikaTheme.Color.mutedForeground)
                        }
                        .padding(.vertical, 4)
                    }
                } else {
                    Section("Target goals") {
                        ForEach(availableGoals) { goal in
                            goalRow(goal)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Paid from a target")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(SikaTheme.Color.sikaAccent)
                }
            }
        }
    }

    private var noneRow: some View {
        Button {
            selectedGoalId = nil
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "xmark.circle")
                    .foregroundStyle(SikaTheme.Color.mutedForeground)
                    .font(.system(size: 16))
                Text("No target")
                    .font(SikaTheme.Typography.sans(15))
                    .foregroundStyle(SikaTheme.Color.foreground)
                Spacer()
                if selectedGoalId == nil {
                    Image(systemName: "checkmark")
                        .foregroundStyle(SikaTheme.Color.sikaAccent)
                        .font(.system(size: 14, weight: .semibold))
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func goalRow(_ goal: Goal) -> some View {
        Button {
            selectedGoalId = goal.id
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Text(IconResolver.resolve(goal.icon))
                    .font(.system(size: 22))
                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.name)
                        .font(SikaTheme.Typography.sans(15, weight: .medium))
                        .foregroundStyle(SikaTheme.Color.foreground)
                    if let target = goal.targetAmount {
                        Text("Target: \(CurrencyFormatter.format(target, code: appState.currencyCode))")
                            .font(SikaTheme.Typography.sans(11))
                            .foregroundStyle(SikaTheme.Color.mutedForeground)
                    }
                }
                Spacer()
                if selectedGoalId == goal.id {
                    Image(systemName: "checkmark")
                        .foregroundStyle(SikaTheme.Color.sikaAccent)
                        .font(.system(size: 14, weight: .semibold))
                }
            }
        }
        .buttonStyle(.plain)
    }
}
