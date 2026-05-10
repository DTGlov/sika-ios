import SwiftUI
import Supabase

/// Bottom sheet for creating or editing a goal.
/// Field order matches audit Section 3.2.
struct GoalFormSheet: View {
    /// nil = create; non-nil = edit
    let editingGoal: Goal?
    let accounts: [Account]
    let onSaved: () async -> Void

    @Environment(AppState.self) private var appState
    @Environment(ToastManager.self) private var toasts
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var description: String = ""
    @State private var icon: String = GoalConstants.defaultIcon
    @State private var color: String = GoalConstants.defaultColor
    @State private var goalType: GoalType = .target
    @State private var targetText: String = ""
    @State private var deadline: Date = Calendar.current.date(byAdding: .month, value: 6, to: Date()) ?? Date()
    @State private var hasDeadline: Bool = true
    @State private var fundingAccountId: UUID? = nil
    @State private var priority: Int = 5

    @State private var isSaving = false

    private var darkText: Color { Color(hex: 0x0E1A2E) }
    private var accentColor: Color { GoalConstants.resolveColor(color) }
    private var isEditing: Bool { editingGoal != nil }

    private var canSubmit: Bool {
        guard !isSaving else { return false }
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        guard fundingAccountId != nil else { return false }
        if goalType == .target {
            guard let target = Decimal(string: targetText), target > 0 else { return false }
            guard hasDeadline else { return false }
        }
        return true
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    iconColorSection
                    nameField
                    descriptionField
                    typeSection
                    if goalType == .target { targetSection }
                    fundingAccountSection
                    prioritySection
                    submitButton
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .navigationTitle(isEditing ? "Edit Goal" : "New Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .background(SikaTheme.Color.background)
        }
        .presentationDetents([.large])
        .onAppear { primeFromInputs() }
    }

    // MARK: - Sections

    private var iconColorSection: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Icon")
                    .font(SikaTheme.Typography.sans(12, weight: .semibold))
                    .foregroundStyle(SikaTheme.Color.foreground)
                FlowLayout(spacing: 6) {
                    ForEach(GoalConstants.icons, id: \.self) { glyph in
                        iconChip(glyph)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 8) {
                Text("Color")
                    .font(SikaTheme.Typography.sans(12, weight: .semibold))
                    .foregroundStyle(SikaTheme.Color.foreground)
                HStack(spacing: 6) {
                    ForEach(GoalConstants.colors, id: \.self) { hex in
                        colorDot(hex)
                    }
                }
            }
        }
    }

    private func iconChip(_ glyph: String) -> some View {
        let isActive = icon == glyph
        return Button {
            icon = glyph
        } label: {
            Text(glyph)
                .font(.system(size: 18))
                .frame(width: 36, height: 36)
                .background(isActive ? accentColor.opacity(0.33) : SikaTheme.Color.muted)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isActive ? accentColor : Color.clear, lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
    }

    private func colorDot(_ hex: String) -> some View {
        let dot = GoalConstants.resolveColor(hex)
        let isActive = color == hex
        return Button {
            color = hex
        } label: {
            ZStack {
                Circle()
                    .fill(dot)
                    .frame(width: 28, height: 28)
                if isActive {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Name")
                .font(SikaTheme.Typography.sans(12, weight: .semibold))
                .foregroundStyle(SikaTheme.Color.foreground)
            TextField("e.g. Vacation 2026", text: $name)
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

    private var descriptionField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Description (optional)")
                .font(SikaTheme.Typography.sans(12, weight: .semibold))
                .foregroundStyle(SikaTheme.Color.foreground)
            TextField("What's it for?", text: $description, axis: .vertical)
                .font(SikaTheme.Typography.sans(14))
                .lineLimit(2...4)
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

    private var typeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Type")
                .font(SikaTheme.Typography.sans(12, weight: .semibold))
                .foregroundStyle(SikaTheme.Color.foreground)
            VStack(spacing: 8) {
                typeOption(.target, title: "Target", subtitle: "A specific amount to reach by a date.")
                typeOption(.perpetual, title: "Perpetual", subtitle: "Ongoing — keep saving without a target.")
            }
        }
    }

    private func typeOption(_ type: GoalType, title: String, subtitle: String) -> some View {
        let isActive = goalType == type
        return Button {
            goalType = type
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isActive ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(isActive ? accentColor : SikaTheme.Color.mutedForeground)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(SikaTheme.Typography.sans(14, weight: .semibold))
                        .foregroundStyle(SikaTheme.Color.foreground)
                    Text(subtitle)
                        .font(SikaTheme.Typography.sans(11))
                        .foregroundStyle(SikaTheme.Color.mutedForeground)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .background(isActive ? accentColor.opacity(0.08) : SikaTheme.Color.card)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isActive ? accentColor : SikaTheme.Color.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
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
                    TextField("5000", text: $targetText)
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

    private var fundingAccountSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Save to")
                .font(SikaTheme.Typography.sans(12, weight: .semibold))
                .foregroundStyle(SikaTheme.Color.foreground)
            Menu {
                ForEach(accounts.filter { $0.archived != true }) { account in
                    Button {
                        fundingAccountId = account.id
                    } label: {
                        Text(account.name)
                    }
                }
            } label: {
                HStack {
                    Text(selectedAccountName)
                        .font(SikaTheme.Typography.sans(15))
                        .foregroundStyle(SikaTheme.Color.foreground)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 12))
                        .foregroundStyle(SikaTheme.Color.mutedForeground)
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
            Text("Contributions go here. Payments come from here.")
                .font(SikaTheme.Typography.sans(11))
                .foregroundStyle(SikaTheme.Color.mutedForeground)
        }
    }

    private var selectedAccountName: String {
        guard let id = fundingAccountId,
              let acc = accounts.first(where: { $0.id == id }) else {
            return "Select account"
        }
        return acc.name
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

    private var submitButton: some View {
        Button {
            Task { await submit() }
        } label: {
            HStack {
                if isSaving { ProgressView().scaleEffect(0.85).tint(darkText) }
                Text(isSaving ? "Saving…" : (isEditing ? "Save Changes" : "Create Goal"))
                    .font(SikaTheme.Typography.sans(15, weight: .semibold))
                    .foregroundStyle(canSubmit ? darkText : SikaTheme.Color.mutedForeground)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(canSubmit ? accentColor : SikaTheme.Color.muted)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(!canSubmit)
        .padding(.top, 8)
    }

    // MARK: - Lifecycle

    private func primeFromInputs() {
        if let g = editingGoal {
            name = g.name
            description = g.description ?? ""
            icon = g.icon ?? GoalConstants.defaultIcon
            color = g.color ?? GoalConstants.defaultColor
            goalType = g.goalType
            targetText = g.targetAmount.map { NSDecimalNumber(decimal: $0).stringValue } ?? ""
            if let str = g.deadline,
               let parsed = GoalEngine.parseDateOnly(str) {
                deadline = parsed
                hasDeadline = true
            }
            fundingAccountId = g.fundingAccountId
            priority = g.priority ?? 5
        } else {
            // Default funding account on create: first non-archived account.
            fundingAccountId = accounts.first(where: { $0.archived != true })?.id
        }
    }

    private func submit() async {
        guard canSubmit, let acc = fundingAccountId else { return }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDesc = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedDesc: String? = trimmedDesc.isEmpty ? nil : trimmedDesc

        let target: Decimal? = (goalType == .target ? Decimal(string: targetText) : nil)
        let deadlineString: String? = (goalType == .target && hasDeadline)
            ? formatDate(deadline)
            : nil

        isSaving = true
        defer { isSaving = false }

        if let editing = editingGoal {
            let payload = GoalService.UpdatePayload(
                name: trimmedName,
                description: resolvedDesc,
                goal_type: goalType.rawValue,
                target_amount: target,
                deadline: deadlineString,
                funding_account_id: acc,
                priority: priority,
                icon: icon,
                color: color
            )
            let result = await appState.updateGoal(id: editing.id, payload: payload)
            if result != nil {
                toasts.show("Goal updated", kind: .success)
                await onSaved()
                dismiss()
            } else {
                toasts.show("Failed to save", kind: .error)
            }
        } else {
            guard let userId = appState.session?.user.id else { return }
            let payload = GoalService.CreatePayload(
                user_id: userId,
                name: trimmedName,
                description: resolvedDesc,
                goal_type: goalType.rawValue,
                target_amount: target,
                deadline: deadlineString,
                funding_account_id: acc,
                priority: priority,
                icon: icon,
                color: color
            )
            let result = await appState.createGoal(payload: payload)
            if result != nil {
                toasts.show("Goal created", kind: .success)
                await onSaved()
                dismiss()
            } else {
                toasts.show("Failed to create goal", kind: .error)
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        return f.string(from: date)
    }
}
