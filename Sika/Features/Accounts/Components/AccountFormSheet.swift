import SwiftUI

/// Bottom sheet for creating or editing an account.
/// Edit mode adds an inline reconcile expander beneath the standard fields.
struct AccountFormSheet: View {
    /// nil = create; non-nil = edit
    let editingAccount: Account?
    /// Computed running balance — passed by the caller. Drives the
    /// "Sika shows" label inside the inline reconcile expander.
    let currentBalance: Decimal
    let currencyCode: String
    let onSaved: () async -> Void

    @Environment(AppState.self) private var appState
    @Environment(ToastManager.self) private var toasts
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var type: AccountType = .bank
    @State private var openingBalanceText: String = ""
    @State private var isDefault: Bool = false
    @State private var isActive: Bool = true

    @State private var showReconcileExpander: Bool = false
    @State private var actualBalanceText: String = ""

    @State private var isSaving = false
    @State private var isReconciling = false

    private var darkText: Color { Color(hex: 0x0E1A2E) }
    private var goldColor: Color { Color(hex: 0xD4A017) }

    private var isEditing: Bool { editingAccount != nil }
    private var titleText: String { isEditing ? "Edit account" : "Add account" }
    private var submitLabel: String { isEditing ? "Save changes" : "Add account" }
    private var cfg: AccountTypeConfig { AccountTypeConfigs.config(for: type) }

    private var openingBalance: Decimal {
        Decimal(string: openingBalanceText.trimmingCharacters(in: .whitespaces)) ?? 0
    }

    private var actualBalance: Decimal {
        Decimal(string: actualBalanceText.trimmingCharacters(in: .whitespaces)) ?? 0
    }

    private var canSubmit: Bool {
        guard !isSaving else { return false }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return !trimmed.isEmpty && openingBalance >= 0
    }

    private var canReconcile: Bool {
        guard !isReconciling else { return false }
        guard !actualBalanceText.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        return actualBalance != currentBalance
    }

    private var reconcileDiff: Decimal {
        actualBalance - currentBalance
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    nameField
                    typeTiles
                    openingBalanceField
                    defaultToggle
                    if isEditing {
                        activeToggle
                        reconcileExpander
                    }
                    if !showReconcileExpander {
                        submitButton
                    }
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

    // MARK: - Standard fields

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Name")
                .font(SikaTheme.Typography.sans(12, weight: .semibold))
                .foregroundStyle(SikaTheme.Color.foreground)
            TextField("e.g. Checking", text: $name)
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

    private var typeTiles: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Type")
                .font(SikaTheme.Typography.sans(12, weight: .semibold))
                .foregroundStyle(SikaTheme.Color.foreground)
            let columns = [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8),
            ]
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(AccountType.allCases) { t in
                    typeTile(t)
                }
            }
        }
    }

    private func typeTile(_ t: AccountType) -> some View {
        let tCfg = AccountTypeConfigs.config(for: t)
        let isActive = type == t
        return Button {
            type = t
        } label: {
            VStack(spacing: 4) {
                Text(tCfg.emoji)
                    .font(.system(size: 18))
                Text(tCfg.label)
                    .font(SikaTheme.Typography.sans(11, weight: .semibold))
                    .foregroundStyle(isActive ? tCfg.color : SikaTheme.Color.mutedForeground)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isActive ? tCfg.color.opacity(0.094) : SikaTheme.Color.card)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isActive ? tCfg.color : SikaTheme.Color.border,
                            lineWidth: isActive ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var openingBalanceField: some View {
        let symbol = CurrencyFormatter.symbol(forCode: currencyCode)
        let label = isEditing
            ? "Opening balance (\(symbol))"
            : "Current balance — RIGHT NOW (\(symbol))"

        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(SikaTheme.Typography.sans(12, weight: .semibold))
                .foregroundStyle(SikaTheme.Color.foreground)
            HStack(spacing: 6) {
                Text(symbol)
                    .font(SikaTheme.Typography.sans(13))
                    .foregroundStyle(SikaTheme.Color.mutedForeground)
                TextField("0.00", text: $openingBalanceText)
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
            if !isEditing {
                Text("Enter the actual balance in this account today — not zero, unless it's empty. Sika adds and subtracts from this as you log transactions.")
                    .font(SikaTheme.Typography.sans(11))
                    .foregroundStyle(SikaTheme.Color.mutedForeground)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var defaultToggle: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(isOn: $isDefault) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Set as default")
                        .font(SikaTheme.Typography.sans(14, weight: .semibold))
                        .foregroundStyle(SikaTheme.Color.foreground)
                    Text("Used for new transactions")
                        .font(SikaTheme.Typography.sans(11))
                        .foregroundStyle(SikaTheme.Color.mutedForeground)
                }
            }
            .tint(goldColor)
        }
    }

    private var activeToggle: some View {
        Toggle(isOn: $isActive) {
            VStack(alignment: .leading, spacing: 2) {
                Text(isActive ? "Active" : "Archived")
                    .font(SikaTheme.Typography.sans(14, weight: .semibold))
                    .foregroundStyle(SikaTheme.Color.foreground)
                Text(isActive
                     ? "Account is visible across the app."
                     : "Account is hidden from pickers and lists.")
                    .font(SikaTheme.Typography.sans(11))
                    .foregroundStyle(SikaTheme.Color.mutedForeground)
            }
        }
        .tint(Color(hex: 0xFBBF24))
    }

    // MARK: - Reconcile expander (edit mode only)

    @ViewBuilder
    private var reconcileExpander: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    showReconcileExpander.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "scalemass")
                        .font(.system(size: 14))
                    Text("Reconcile to real balance")
                        .font(SikaTheme.Typography.sans(13, weight: .semibold))
                    Spacer(minLength: 0)
                    Image(systemName: showReconcileExpander ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(SikaTheme.Color.foreground)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(SikaTheme.Color.muted)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)

            if showReconcileExpander {
                reconcileBody
            }
        }
    }

    @ViewBuilder
    private var reconcileBody: some View {
        let symbol = CurrencyFormatter.symbol(forCode: currencyCode)

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Sika shows")
                    .font(SikaTheme.Typography.sans(12))
                    .foregroundStyle(SikaTheme.Color.mutedForeground)
                Spacer()
                Text(CurrencyFormatter.format(currentBalance, code: currencyCode))
                    .font(SikaTheme.Typography.sans(13, weight: .semibold))
                    .foregroundStyle(SikaTheme.Color.foreground)
                    .monospacedDigit()
            }

            HStack(spacing: 6) {
                Text(symbol)
                    .font(SikaTheme.Typography.sans(13))
                    .foregroundStyle(SikaTheme.Color.mutedForeground)
                TextField("Actual current balance", text: $actualBalanceText)
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

            if !actualBalanceText.trimmingCharacters(in: .whitespaces).isEmpty {
                diffCard
            }

            Button {
                Task { await commitReconcile() }
            } label: {
                HStack {
                    if isReconciling { ProgressView().scaleEffect(0.85).tint(darkText) }
                    Text(isReconciling ? "Saving…" : "Create adjustment & close")
                        .font(SikaTheme.Typography.sans(15, weight: .semibold))
                        .foregroundStyle(canReconcile ? darkText : SikaTheme.Color.mutedForeground)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(canReconcile ? goldColor : SikaTheme.Color.muted)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .disabled(!canReconcile)
        }
        .padding(14)
        .background(SikaTheme.Color.card)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(SikaTheme.Color.border, lineWidth: 1)
        )
    }

    private var diffCard: some View {
        let isPositive = reconcileDiff >= 0
        let color = isPositive ? Color(hex: 0x00D9A3) : Color(hex: 0xF43F5E)
        let abs: Decimal = isPositive ? reconcileDiff : -reconcileDiff
        let sign = isPositive ? "+" : "−"

        return HStack {
            Text("Adjustment")
                .font(SikaTheme.Typography.sans(12, weight: .semibold))
                .foregroundStyle(color)
            Spacer()
            Text("\(sign)\(CurrencyFormatter.format(abs, code: currencyCode))")
                .font(SikaTheme.Typography.sans(13, weight: .bold))
                .foregroundStyle(color)
                .monospacedDigit()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(color.opacity(0.094))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Submit (Add / Save)

    private var submitButton: some View {
        Button {
            Task { await submit() }
        } label: {
            HStack {
                if isSaving { ProgressView().scaleEffect(0.85).tint(darkText) }
                Text(isSaving ? "Saving…" : submitLabel)
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

    // MARK: - Lifecycle

    private func primeFromInputs() {
        if let acc = editingAccount {
            name = acc.name
            type = acc.accountType
            openingBalanceText = (acc.openingBalance.map {
                NSDecimalNumber(decimal: $0).stringValue
            }) ?? "0"
            isDefault = acc.isDefault ?? false
            isActive = acc.isActive ?? true
        } else {
            name = ""
            type = .bank
            openingBalanceText = ""
            isDefault = false
            isActive = true
        }
    }

    private func submit() async {
        guard canSubmit else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)

        isSaving = true
        defer { isSaving = false }

        if let acc = editingAccount {
            let result = await appState.updateAccount(
                id: acc.id,
                name: trimmed,
                type: type,
                openingBalance: openingBalance,
                isDefault: isDefault,
                isActive: isActive
            )
            if result != nil {
                toasts.show("Account updated", kind: .success)
                await onSaved()
                dismiss()
            } else {
                toasts.show("Failed to save", kind: .error)
            }
        } else {
            let result = await appState.createAccount(
                name: trimmed,
                type: type,
                openingBalance: openingBalance,
                isDefault: isDefault
            )
            if result != nil {
                toasts.show("Account created", kind: .success)
                await onSaved()
                dismiss()
            } else {
                toasts.show("Failed to create account", kind: .error)
            }
        }
    }

    private func commitReconcile() async {
        guard let acc = editingAccount else { return }
        guard canReconcile else {
            if reconcileDiff == 0 {
                toasts.show("Balance already matches", kind: .info)
            }
            return
        }
        isReconciling = true
        defer { isReconciling = false }

        let ok = await appState.reconcileAccountInline(
            accountId: acc.id,
            sikaBalance: currentBalance,
            actualBalance: actualBalance
        )
        if ok {
            let formatted = CurrencyFormatter.format(actualBalance, code: currencyCode)
            toasts.show("Reconciled to \(formatted)", kind: .success)
            await onSaved()
            dismiss()
        } else {
            toasts.show("Failed to reconcile", kind: .error)
        }
    }
}
