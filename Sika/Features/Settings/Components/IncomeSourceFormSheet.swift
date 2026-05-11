import SwiftUI

/// Bottom sheet for creating or editing an income source.
/// Field order mirrors audit Section 5.2.
///
/// Validation:
/// - name non-empty (trimmed)
/// - amount > 0
/// - frequency is required (default monthly)
/// - expectedDay may be nil — submit allowed but the row will render the
///   AlertCircle warning until the user fills it in
///
/// Submit is non-optimistic — the button shows a spinner until the
/// round-trip completes, then the sheet dismisses on success.
struct IncomeSourceFormSheet: View {
    /// nil = create; non-nil = edit
    let editingSource: IncomeSource?
    /// Optional template used to pre-fill a fresh create.
    let templateDefaults: IncomeSourceTemplate?
    let accounts: [Account]
    let onSaved: () async -> Void

    @Environment(AppState.self) private var appState
    @Environment(ToastManager.self) private var toasts
    @Environment(\.dismiss) private var dismiss

    // Form state
    @State private var name: String = ""
    @State private var amountText: String = ""
    @State private var frequency: IncomeFrequency = .monthly
    @State private var expectedDay: Int? = nil
    @State private var icon: String = "💰"
    @State private var accountId: UUID? = nil
    @State private var isActive: Bool = true

    @State private var isSubmitting = false

    private let goldColor = Color(hex: 0xD4A017)
    private let darkText = Color(hex: 0x0E1A2E)
    private let warningColor = Color(hex: 0xFBBF24)

    // 12 income-flavored emojis. Audit Section 5.2.2 didn't ship in the
    // iOS repo (web-only doc) — this set was chosen to map to common
    // income types without overlapping the goal/recurring emoji vocab.
    private let iconOptions: [String] = [
        "💰", "💼", "🎁", "💻",
        "📈", "🏦", "💵", "💳",
        "🪙", "📊", "🧾", "🤝"
    ]

    private var isEditing: Bool { editingSource != nil }
    private var titleText: String { isEditing ? "Edit income source" : "New income source" }
    private var submitLabel: String { isEditing ? "Save changes" : "Add source" }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var parsedAmount: Decimal? {
        let trimmed = amountText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return Decimal(string: trimmed)
    }

    private var canSubmit: Bool {
        guard !isSubmitting else { return false }
        guard !trimmedName.isEmpty, trimmedName.count <= 80 else { return false }
        guard let amount = parsedAmount, amount > 0 else { return false }
        return true
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    nameField
                    iconField
                    amountField
                    frequencySection
                    expectedDaySection
                    accountField
                    if isEditing { activeToggle }
                    submitButton
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .navigationTitle(titleText)
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

    // MARK: - Fields

    private var nameField: some View {
        FieldLabel("Name") {
            TextField("e.g. Salary", text: $name)
                .font(SikaTheme.Typography.sans(15))
                .textInputAutocapitalization(.words)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(SikaTheme.Color.card)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(SikaTheme.Color.border, lineWidth: 1)
                )
                .onChange(of: name) { _, newValue in
                    if newValue.count > 80 { name = String(newValue.prefix(80)) }
                }
        }
    }

    private var iconField: some View {
        FieldLabel("Icon") {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6),
                spacing: 8
            ) {
                ForEach(iconOptions, id: \.self) { emoji in
                    iconButton(emoji)
                }
            }
        }
    }

    private func iconButton(_ emoji: String) -> some View {
        let isActiveIcon = (icon == emoji)
        return Button {
            icon = emoji
        } label: {
            Text(emoji)
                .font(.system(size: 22))
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(isActiveIcon ? goldColor.opacity(0.15) : SikaTheme.Color.card)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            isActiveIcon ? goldColor : SikaTheme.Color.border,
                            lineWidth: isActiveIcon ? 1.5 : 1
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private var amountField: some View {
        FieldLabel("Amount") {
            HStack(spacing: 6) {
                Text(CurrencyFormatter.symbol(forCode: appState.currencyCode))
                    .font(SikaTheme.Typography.sans(13))
                    .foregroundStyle(SikaTheme.Color.mutedForeground)
                TextField("0.00", text: $amountText)
                    .keyboardType(.decimalPad)
                    .font(SikaTheme.Typography.sans(15, weight: .semibold))
                    .foregroundStyle(SikaTheme.Color.foreground)
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
    }

    private var frequencySection: some View {
        FieldLabel("Frequency") {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2),
                spacing: 8
            ) {
                ForEach(IncomeFrequency.allCases) { freq in
                    frequencyChip(freq)
                }
            }
        }
    }

    private func frequencyChip(_ freq: IncomeFrequency) -> some View {
        let greenColor = Color(hex: 0x00D9A3)
        let isActiveFreq = (frequency == freq)
        return Button {
            if frequency != freq {
                frequency = freq
                expectedDay = nil
            }
        } label: {
            Text(freq.displayName)
                .font(SikaTheme.Typography.sans(13, weight: isActiveFreq ? .semibold : .regular))
                .foregroundStyle(isActiveFreq ? greenColor : SikaTheme.Color.foreground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isActiveFreq ? greenColor.opacity(0.10) : SikaTheme.Color.card)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            isActiveFreq ? greenColor : SikaTheme.Color.border,
                            lineWidth: isActiveFreq ? 1.5 : 1
                        )
                )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var expectedDaySection: some View {
        switch frequency {
        case .monthly:
            FieldLabel("Day of month") {
                DayOfMonthStepperView(selectedDay: $expectedDay)
            }
        case .weekly, .biweekly:
            FieldLabel("Day of week") {
                DayOfWeekPickerView(selectedDay: $expectedDay)
            }
        case .irregular:
            EmptyView()
        }
    }

    private var accountField: some View {
        FieldLabel("Account (optional)") {
            Menu {
                Button { accountId = nil } label: { Text("No account") }
                ForEach(accounts.filter { $0.isActive != false }) { account in
                    Button { accountId = account.id } label: { Text(account.name) }
                }
            } label: {
                menuRowLabel(
                    accountId.flatMap { id in accounts.first(where: { $0.id == id })?.name } ?? "No account"
                )
            }
        }
    }

    private var activeToggle: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: $isActive) {
                Text("Active")
                    .font(SikaTheme.Typography.sans(14, weight: .semibold))
                    .foregroundStyle(SikaTheme.Color.foreground)
            }
            .tint(goldColor)
            Text(isActive
                 ? "Included in your total monthly income."
                 : "Excluded from your total monthly income until re-activated.")
                .font(SikaTheme.Typography.sans(11))
                .foregroundStyle(SikaTheme.Color.mutedForeground)
        }
    }

    private var submitButton: some View {
        Button {
            Task { await submit() }
        } label: {
            HStack {
                if isSubmitting {
                    ProgressView().scaleEffect(0.85).tint(darkText)
                }
                Text(submitLabel)
                    .font(SikaTheme.Typography.sans(15, weight: .semibold))
                    .foregroundStyle(canSubmit ? darkText : SikaTheme.Color.mutedForeground)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(canSubmit ? goldColor : SikaTheme.Color.muted)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(!canSubmit)
        .padding(.top, 8)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func FieldLabel<Content: View>(
        _ label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(SikaTheme.Typography.sans(12, weight: .semibold))
                .foregroundStyle(SikaTheme.Color.foreground)
            content()
        }
    }

    private func menuRowLabel(_ text: String) -> some View {
        HStack {
            Text(text)
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

    // MARK: - Pre-fill + submit

    private func primeFromInputs() {
        if let source = editingSource {
            name = source.name
            amountText = NSDecimalNumber(decimal: source.amount).stringValue
            frequency = source.frequency
            expectedDay = source.expectedDay
            icon = source.icon ?? "💰"
            accountId = source.accountId
            isActive = source.isActive
        } else if let template = templateDefaults {
            name = template.label
            frequency = template.frequency
            expectedDay = template.suggestedExpectedDay
            icon = template.emoji
            isActive = true
        }
    }

    private func submit() async {
        guard canSubmit, let amount = parsedAmount else { return }

        isSubmitting = true
        defer { isSubmitting = false }

        let success: Bool
        if let editing = editingSource {
            success = await appState.updateIncomeSource(
                id: editing.id,
                name: trimmedName,
                amount: amount,
                frequency: frequency,
                expectedDay: expectedDay,
                icon: icon,
                accountId: accountId,
                isActive: isActive
            )
        } else {
            success = await appState.createIncomeSource(
                name: trimmedName,
                amount: amount,
                frequency: frequency,
                expectedDay: expectedDay,
                icon: icon,
                accountId: accountId,
                isActive: true
            )
        }

        if success {
            toasts.show(isEditing ? "Income source updated" : "Income source created", kind: .success)
            await onSaved()
            dismiss()
        } else {
            toasts.show("Failed to save", kind: .error)
        }
    }
}

/// Day-of-month stepper (1...31) with optional clear. Tailored to income
/// sources where the user may want to leave the day blank initially and
/// fill it later (driving the AlertCircle inline warning).
private struct DayOfMonthStepperView: View {
    @Binding var selectedDay: Int?

    @State private var text: String = ""

    private let greenColor = Color(hex: 0x00D9A3)

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Text("Day")
                    .font(SikaTheme.Typography.sans(11))
                    .foregroundStyle(SikaTheme.Color.mutedForeground)
                TextField("1–31", text: $text)
                    .keyboardType(.numberPad)
                    .font(SikaTheme.Typography.sans(15, weight: .semibold))
                    .foregroundStyle(SikaTheme.Color.foreground)
                    .frame(width: 56)
                    .multilineTextAlignment(.center)
                    .onChange(of: text) { _, newValue in
                        handleTextChange(newValue)
                    }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(SikaTheme.Color.card)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        selectedDay != nil ? greenColor : SikaTheme.Color.border,
                        lineWidth: 1
                    )
            )

            if selectedDay != nil {
                Button {
                    selectedDay = nil
                    text = ""
                } label: {
                    Text("Clear")
                        .font(SikaTheme.Typography.sans(12, weight: .semibold))
                        .foregroundStyle(SikaTheme.Color.mutedForeground)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(SikaTheme.Color.muted)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .onAppear { syncTextFromBinding() }
        .onChange(of: selectedDay) { _, _ in syncTextFromBinding() }
    }

    private func handleTextChange(_ newValue: String) {
        let filtered = newValue.filter { $0.isNumber }
        if filtered.isEmpty {
            selectedDay = nil
            if text != filtered { text = filtered }
            return
        }
        if let parsed = Int(filtered) {
            let clamped = min(max(parsed, 1), 31)
            selectedDay = clamped
            let clampedText = String(clamped)
            if text != clampedText { text = clampedText }
        }
    }

    private func syncTextFromBinding() {
        if let day = selectedDay {
            let value = String(day)
            if text != value { text = value }
        } else {
            if text != "" { text = "" }
        }
    }
}
