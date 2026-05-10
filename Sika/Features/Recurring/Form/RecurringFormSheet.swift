import SwiftUI
import Supabase

/// Bottom sheet for creating or editing a recurring transaction.
/// Field order matches audit Section 4.
///
/// New rows always type=.expense (no type picker); income recurrings are
/// legacy and only become editable when the editingItem already has type=.income.
///
/// Submit is non-optimistic — the button shows a spinner until the round-trip
/// completes, then the sheet dismisses on success.
struct RecurringFormSheet: View {
    /// nil = create; non-nil = edit
    let editingItem: RecurringTransaction?
    /// Optional template defaults used to pre-fill a fresh form on Add.
    let templateDefaults: QuickTemplate?
    let accounts: [Account]
    let categories: [TransactionCategory]
    let onSaved: () async -> Void

    @Environment(AppState.self) private var appState
    @Environment(ToastManager.self) private var toasts
    @Environment(\.dismiss) private var dismiss

    // Form state
    @State private var amountText: String = ""
    @State private var accountId: UUID? = nil
    @State private var categoryId: UUID? = nil
    @State private var note: String = ""
    @State private var frequency: RecurringFrequency = .monthly
    @State private var scheduleDay: Int? = nil
    @State private var startDate: Date = Date()
    @State private var endDate: Date? = nil
    @State private var autoLog: Bool = true
    @State private var isPaused: Bool = false

    @State private var isSubmitting = false

    private let goldColor = Color(hex: 0xD4A017)
    private let darkText = Color(hex: 0x0E1A2E)

    private var isEditing: Bool { editingItem != nil }
    private var titleText: String { isEditing ? "Edit recurring" : "New recurring transaction" }
    private var submitLabel: String { isEditing ? "Save changes" : "Create" }

    private var canSubmit: Bool {
        guard !isSubmitting else { return false }
        guard let amount = Decimal(string: amountText), amount > 0 else { return false }
        guard accountId != nil else { return false }
        switch frequency {
        case .weekly, .biweekly, .monthly:
            return scheduleDay != nil
        case .daily, .yearly:
            return true
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    amountField
                    accountField
                    categoryField
                    noteField
                    frequencySection
                    scheduleDaySection
                    startDateField
                    endDateField
                    autoLogToggle
                    if isEditing { pausedToggle }
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

    private var amountField: some View {
        FieldLabel("Amount") {
            HStack(spacing: 6) {
                Text("GHS")
                    .font(SikaTheme.Typography.sans(13))
                    .foregroundStyle(SikaTheme.Color.mutedForeground)
                TextField("0.00", text: $amountText)
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
    }

    private var accountField: some View {
        FieldLabel("Account") {
            Menu {
                ForEach(accounts.filter { $0.archived != true }) { account in
                    Button {
                        accountId = account.id
                    } label: {
                        Label(account.name, systemImage: "wallet.pass")
                    }
                }
            } label: {
                menuRowLabel(accountId.flatMap { id in accounts.first(where: { $0.id == id })?.name } ?? "Select account")
            }
        }
    }

    private var categoryField: some View {
        FieldLabel("Category (optional)") {
            Menu {
                Button { categoryId = nil } label: { Text("No category") }
                ForEach(categories.filter { $0.archived != true && $0.categoryType == .expense }) { cat in
                    Button { categoryId = cat.id } label: { Text(cat.name) }
                }
            } label: {
                menuRowLabel(categoryId.flatMap { id in categories.first(where: { $0.id == id })?.name } ?? "No category")
            }
        }
    }

    private var noteField: some View {
        FieldLabel("Note (optional)") {
            TextField("e.g. Monthly rent", text: $note)
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

    private var frequencySection: some View {
        FieldLabel("Frequency") {
            FrequencyChipsView(selected: $frequency, onChange: { _ in
                scheduleDay = nil
            })
        }
    }

    @ViewBuilder
    private var scheduleDaySection: some View {
        switch frequency {
        case .weekly, .biweekly:
            FieldLabel("Day of week") {
                DayOfWeekPickerView(selectedDay: $scheduleDay)
            }
        case .monthly:
            FieldLabel("Day of month") {
                DayOfMonthPickerView(selectedDay: $scheduleDay)
            }
        case .daily, .yearly:
            EmptyView()
        }
    }

    private var startDateField: some View {
        FieldLabel("Start date") {
            DatePicker("", selection: $startDate, displayedComponents: .date)
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

    @ViewBuilder
    private var endDateField: some View {
        if let _ = endDate {
            FieldLabel("End date") {
                HStack {
                    DatePicker(
                        "",
                        selection: Binding(
                            get: { endDate ?? Date() },
                            set: { endDate = $0 }
                        ),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                    .labelsHidden()

                    Spacer()

                    Button("Remove") { endDate = nil }
                        .font(SikaTheme.Typography.sans(13, weight: .semibold))
                        .foregroundStyle(goldColor)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(SikaTheme.Color.card)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(SikaTheme.Color.border, lineWidth: 1)
                )
            }
        } else {
            Button {
                endDate = Date()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle")
                    Text("Add end date (optional)")
                }
                .font(SikaTheme.Typography.sans(13, weight: .semibold))
                .foregroundStyle(goldColor)
            }
            .buttonStyle(.plain)
        }
    }

    private var autoLogToggle: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: $autoLog) {
                Text("Auto-log this transaction")
                    .font(SikaTheme.Typography.sans(14, weight: .semibold))
                    .foregroundStyle(SikaTheme.Color.foreground)
            }
            .tint(goldColor)
            Text(autoLog
                 ? "We'll log it automatically each period."
                 : "We'll nudge you each period and you confirm.")
                .font(SikaTheme.Typography.sans(11))
                .foregroundStyle(SikaTheme.Color.mutedForeground)
        }
    }

    private var pausedToggle: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: $isPaused) {
                Text("Paused")
                    .font(SikaTheme.Typography.sans(14, weight: .semibold))
                    .foregroundStyle(SikaTheme.Color.foreground)
            }
            .tint(Color(hex: 0xFBBF24))
            Text(isPaused
                 ? "While paused, this rule won't generate transactions or send nudges."
                 : "Active.")
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
        if let item = editingItem {
            amountText = NSDecimalNumber(decimal: item.amount).stringValue
            accountId = item.accountId
            categoryId = item.categoryId
            note = item.note ?? ""
            frequency = item.frequency
            scheduleDay = item.scheduleDay
            startDate = parseDate(item.startDate) ?? Date()
            endDate = item.endDate.flatMap(parseDate)
            autoLog = item.autoLog
            isPaused = item.isPaused
        } else if let template = templateDefaults {
            frequency = template.frequency
            autoLog = template.autoLog
            note = template.note
        } else {
            // Default expense, monthly, auto-log on, today.
        }
    }

    private func submit() async {
        guard canSubmit, let amount = Decimal(string: amountText), let acc = accountId else { return }
        guard let userId = appState.session?.user.id else { return }

        isSubmitting = true
        defer { isSubmitting = false }

        // For new rows we always force expense. Editing preserves the item's
        // original type (which may legitimately be .income for legacy rows).
        let resolvedType: TransactionType = editingItem?.type ?? .expense

        let payload = RecurringPayload(
            user_id: userId,
            type: resolvedType,
            amount: amount,
            account_id: acc,
            category_id: categoryId,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : note,
            frequency: frequency,
            schedule_day: scheduleDay,
            start_date: formatDate(startDate),
            end_date: endDate.map(formatDate),
            auto_log: autoLog,
            is_paused: isEditing ? isPaused : false
        )

        do {
            let service = RecurringService()
            if let editing = editingItem {
                _ = try await service.update(id: editing.id, payload: payload)
                toasts.show("Updated", kind: .success)
            } else {
                _ = try await service.create(payload: payload)
                toasts.show("Recurring transaction created", kind: .success)
            }
            await onSaved()
            dismiss()
        } catch {
            #if DEBUG
            print("⚠️ RecurringFormSheet submit failed: \(error)")
            #endif
            toasts.show("Failed to save", kind: .error)
        }
    }

    private func parseDate(_ str: String) -> Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        return f.date(from: str)
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        return f.string(from: date)
    }
}
