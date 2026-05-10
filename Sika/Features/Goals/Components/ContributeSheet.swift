import SwiftUI

/// Bottom sheet for contributing to a goal. Spring-animated progress preview.
/// Submits via AppState.contributeToGoal which fires the full mutation chain.
struct ContributeSheet: View {
    let goal: Goal
    let progress: GoalProgress?
    let onContributed: () async -> Void

    @Environment(AppState.self) private var appState
    @Environment(ToastManager.self) private var toasts
    @Environment(\.dismiss) private var dismiss

    @State private var fromAccountId: UUID? = nil
    @State private var amountText: String = ""
    @State private var transactionDate: Date = Date()
    @State private var note: String = ""
    @State private var isSubmitting = false

    private var accentColor: Color { GoalConstants.resolveColor(goal.color) }
    private var darkText: Color { Color(hex: 0x0E1A2E) }

    private var amountDecimal: Decimal {
        Decimal(string: amountText.trimmingCharacters(in: .whitespaces)) ?? 0
    }

    private var canSubmit: Bool {
        !isSubmitting && amountDecimal > 0 && fromAccountId != nil
    }

    private var fromAccounts: [Account] {
        appState.accounts.filter { $0.isActive != false && $0.id != goal.fundingAccountId }
    }

    private var currentAmount: Decimal { progress?.currentAmount ?? 0 }
    private var afterAmount: Decimal { currentAmount + amountDecimal }

    private var currentPct: Double {
        guard let target = goal.targetAmount, target > 0 else { return 0 }
        let pct = (NSDecimalNumber(decimal: currentAmount).doubleValue
                   / NSDecimalNumber(decimal: target).doubleValue) * 100.0
        return min(100, max(0, pct))
    }

    private var afterPct: Double {
        guard let target = goal.targetAmount, target > 0 else { return 0 }
        let pct = (NSDecimalNumber(decimal: afterAmount).doubleValue
                   / NSDecimalNumber(decimal: target).doubleValue) * 100.0
        return min(100, max(0, pct))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    previewCard
                    fromAccountField
                    amountField
                    dateField
                    noteField
                    submitButton
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .navigationTitle("Contribute")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .background(SikaTheme.Color.background)
        }
        .presentationDetents([.large])
        .onAppear {
            fromAccountId = fromAccounts.first?.id
        }
    }

    // MARK: - Preview card

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text(goal.icon ?? GoalConstants.defaultIcon)
                    .font(.system(size: 22))
                    .frame(width: 40, height: 40)
                    .background(accentColor.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.name)
                        .font(SikaTheme.Typography.sans(15, weight: .bold))
                        .foregroundStyle(SikaTheme.Color.foreground)
                        .lineLimit(1)
                    if let target = goal.targetAmount {
                        Text("\(CurrencyFormatter.format(afterAmount, code: appState.currencyCode)) of \(CurrencyFormatter.format(target, code: appState.currencyCode))")
                            .font(SikaTheme.Typography.sans(12))
                            .foregroundStyle(SikaTheme.Color.mutedForeground)
                            .monospacedDigit()
                    } else {
                        Text(CurrencyFormatter.format(afterAmount, code: appState.currencyCode))
                            .font(SikaTheme.Typography.sans(12))
                            .foregroundStyle(SikaTheme.Color.mutedForeground)
                            .monospacedDigit()
                    }
                }
                Spacer(minLength: 0)
            }

            // Progress preview only for target goals.
            if goal.goalType == .target {
                progressPreview
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(accentColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(accentColor.opacity(0.30), lineWidth: 1)
        )
    }

    private var progressPreview: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(SikaTheme.Color.muted)
                    .frame(height: 10)
                GeometryReader { geo in
                    Capsule()
                        .fill(accentColor)
                        .frame(width: geo.size.width * CGFloat(afterPct / 100.0), height: 10)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: afterPct)
                }
                .frame(height: 10)
            }
            HStack {
                Text("Current: \(CurrencyFormatter.format(currentAmount, code: appState.currencyCode))")
                    .font(.system(size: 11))
                    .foregroundStyle(SikaTheme.Color.mutedForeground)
                    .monospacedDigit()
                Spacer()
                if amountDecimal > 0 {
                    Text("+\(CurrencyFormatter.format(amountDecimal, code: appState.currencyCode))")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(accentColor)
                        .monospacedDigit()
                }
            }
        }
    }

    // MARK: - Fields

    private var fromAccountField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("From account")
                .font(SikaTheme.Typography.sans(12, weight: .semibold))
                .foregroundStyle(SikaTheme.Color.foreground)
            Menu {
                ForEach(fromAccounts) { acc in
                    Button { fromAccountId = acc.id } label: { Text(acc.name) }
                }
            } label: {
                HStack {
                    Text(selectedFromName)
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
        }
    }

    private var selectedFromName: String {
        guard let id = fromAccountId,
              let acc = fromAccounts.first(where: { $0.id == id }) else {
            return "Select account"
        }
        return acc.name
    }

    private var amountField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Amount")
                .font(SikaTheme.Typography.sans(12, weight: .semibold))
                .foregroundStyle(SikaTheme.Color.foreground)
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

    private var dateField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Date")
                .font(SikaTheme.Typography.sans(12, weight: .semibold))
                .foregroundStyle(SikaTheme.Color.foreground)
            DatePicker("", selection: $transactionDate, displayedComponents: .date)
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

    private var noteField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Note (optional)")
                .font(SikaTheme.Typography.sans(12, weight: .semibold))
                .foregroundStyle(SikaTheme.Color.foreground)
            TextField("Contribution to \(goal.name)", text: $note)
                .font(SikaTheme.Typography.sans(14))
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

    private var submitButton: some View {
        Button {
            Task { await submit() }
        } label: {
            HStack {
                if isSubmitting { ProgressView().scaleEffect(0.85).tint(darkText) }
                Text(isSubmitting ? "Adding…" : "Add Contribution")
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

    private func submit() async {
        guard canSubmit, let from = fromAccountId else { return }

        isSubmitting = true
        defer { isSubmitting = false }

        let dateStr: String = {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            f.locale = Locale(identifier: "en_US_POSIX")
            f.timeZone = .current
            return f.string(from: transactionDate)
        }()

        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedNote: String? = trimmedNote.isEmpty ? nil : trimmedNote

        let ok = await appState.contributeToGoal(
            goal: goal,
            fromAccountId: from,
            amount: amountDecimal,
            note: resolvedNote,
            transactionDate: dateStr
        )

        if ok {
            let formatted = CurrencyFormatter.format(amountDecimal, code: appState.currencyCode)
            toasts.show("\(formatted) added to \(goal.name)", kind: .success)
            await onContributed()
            dismiss()
        } else {
            toasts.show("Failed to contribute", kind: .error)
        }
    }
}
