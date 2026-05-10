import SwiftUI

/// Bottom sheet to start the next cycle of a completed target goal.
/// Pre-fills name (suggestNextCycleName) + deadline (+6 months) + carries
/// target/priority forward.
struct NextCycleSheet: View {
    let completedGoal: Goal
    let onStarted: (Goal) async -> Void

    @Environment(AppState.self) private var appState
    @Environment(ToastManager.self) private var toasts
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var targetText: String = ""
    @State private var deadline: Date = Date()
    @State private var priority: Int = 5
    @State private var isStarting = false

    private var accentColor: Color { GoalConstants.resolveColor(completedGoal.color) }
    private var darkText: Color { Color(hex: 0x0E1A2E) }

    private var canStart: Bool {
        !isStarting
            && !name.trimmingCharacters(in: .whitespaces).isEmpty
            && (Decimal(string: targetText) ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    introCopy
                    nameField
                    targetSection
                    prioritySection
                    startButton
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .navigationTitle("Start Next Cycle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .background(SikaTheme.Color.background)
        }
        .presentationDetents([.large])
        .onAppear { primeFromCompleted() }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text(completedGoal.icon ?? GoalConstants.defaultIcon)
                .font(.system(size: 28))
                .frame(width: 56, height: 56)
                .background(accentColor.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 2) {
                Text("GOAL COMPLETED!")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(accentColor)
                Text(completedGoal.name)
                    .font(SikaTheme.Typography.sans(20, weight: .bold))
                    .foregroundStyle(SikaTheme.Color.foreground)
            }
            Spacer(minLength: 0)
        }
    }

    private var introCopy: some View {
        let target = completedGoal.targetAmount.map {
            CurrencyFormatter.format($0, code: appState.currencyCode)
        } ?? ""
        return Text("You successfully saved and paid \(target). Want to start the next cycle?")
            .font(SikaTheme.Typography.sans(13))
            .foregroundStyle(SikaTheme.Color.mutedForeground)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Name")
                .font(SikaTheme.Typography.sans(12, weight: .semibold))
                .foregroundStyle(SikaTheme.Color.foreground)
            TextField("Cycle name", text: $name)
                .font(SikaTheme.Typography.sans(15))
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(SikaTheme.Color.card)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(SikaTheme.Color.border, lineWidth: 1)
                )
        }
    }

    private var targetSection: some View {
        HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Target Amount")
                    .font(SikaTheme.Typography.sans(12, weight: .semibold))
                    .foregroundStyle(SikaTheme.Color.foreground)
                HStack(spacing: 4) {
                    Text("GHS")
                        .font(SikaTheme.Typography.sans(11))
                        .foregroundStyle(SikaTheme.Color.mutedForeground)
                    TextField("Amount", text: $targetText)
                        .keyboardType(.decimalPad)
                        .font(SikaTheme.Typography.sans(15, weight: .semibold))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(SikaTheme.Color.card)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(SikaTheme.Color.border, lineWidth: 1)
                )
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Deadline")
                    .font(SikaTheme.Typography.sans(12, weight: .semibold))
                    .foregroundStyle(SikaTheme.Color.foreground)
                DatePicker("", selection: $deadline, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(SikaTheme.Color.card)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(SikaTheme.Color.border, lineWidth: 1)
                    )
            }
        }
    }

    private var prioritySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Priority: \(priority)  (1 = highest)")
                .font(SikaTheme.Typography.sans(12, weight: .semibold))
                .foregroundStyle(SikaTheme.Color.foreground)
            Slider(value: Binding(
                get: { Double(priority) },
                set: { priority = Int($0.rounded()) }
            ), in: 1...10, step: 1)
            .tint(accentColor)
        }
    }

    private var startButton: some View {
        Button {
            Task { await startCycle() }
        } label: {
            HStack {
                if isStarting { ProgressView().scaleEffect(0.85).tint(darkText) }
                Text(isStarting ? "Starting…" : "Start Cycle")
                    .font(SikaTheme.Typography.sans(15, weight: .semibold))
                    .foregroundStyle(canStart ? darkText : SikaTheme.Color.mutedForeground)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(canStart ? accentColor : SikaTheme.Color.muted)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(!canStart)
        .padding(.top, 8)
    }

    // MARK: - Lifecycle

    private func primeFromCompleted() {
        let completionDate = completedGoal.completedAt ?? Date()
        name = GoalEngine.suggestNextCycleName(
            currentName: completedGoal.name,
            completionDate: completionDate
        )
        if let target = completedGoal.targetAmount {
            targetText = NSDecimalNumber(decimal: target).stringValue
        }
        deadline = Calendar.current.date(byAdding: .month, value: 6, to: completionDate) ?? Date()
        priority = completedGoal.priority ?? 5
    }

    private func startCycle() async {
        guard canStart, let target = Decimal(string: targetText) else { return }

        isStarting = true
        defer { isStarting = false }

        let deadlineStr: String = {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            f.locale = Locale(identifier: "en_US_POSIX")
            f.timeZone = .current
            return f.string(from: deadline)
        }()

        guard let newGoal = await appState.startNextGoalCycle(
            completedGoal: completedGoal,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            targetAmount: target,
            deadline: deadlineStr,
            priority: priority
        ) else {
            toasts.show("Failed to start cycle", kind: .error)
            return
        }

        toasts.show("New cycle started. Keep saving! 🎯", kind: .success)
        await onStarted(newGoal)
        dismiss()
    }
}
