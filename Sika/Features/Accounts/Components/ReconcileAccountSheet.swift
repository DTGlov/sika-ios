import SwiftUI

/// Standalone reconcile sheet — entry point from the ⚖️ icon on each row.
///
/// Same submit logic as the inline expander on the Edit form: insert an
/// adjustment transaction for the diff via `AppState.reconcileAccountInline`.
///
/// TODO (Phase 9.5b): port `awardMomentum(.accountReconciled)` and
/// `checkAndUnlockBadges(.accountReconciled)` for both reconcile paths.
struct ReconcileAccountSheet: View {
    let account: Account
    let currentBalance: Decimal
    let currencyCode: String
    let onCompleted: () async -> Void

    @Environment(AppState.self) private var appState
    @Environment(ToastManager.self) private var toasts
    @Environment(\.dismiss) private var dismiss

    @State private var actualBalanceText: String = ""
    @State private var isReconciling: Bool = false

    private var darkText: Color { Color(hex: 0x0E1A2E) }
    private var goldColor: Color { Color(hex: 0xD4A017) }

    private var actualBalance: Decimal {
        Decimal(string: actualBalanceText.trimmingCharacters(in: .whitespaces)) ?? 0
    }

    private var diff: Decimal { actualBalance - currentBalance }

    private var canSubmit: Bool {
        !isReconciling
            && !actualBalanceText.trimmingCharacters(in: .whitespaces).isEmpty
            && diff != 0
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                header
                sikaBalanceRow
                actualField
                if !actualBalanceText.trimmingCharacters(in: .whitespaces).isEmpty {
                    diffCard
                }
                submitButton
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(SikaTheme.Color.background)
            .navigationTitle("Reconcile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var header: some View {
        let cfg = AccountTypeConfigs.config(for: account.accountType)
        return HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(cfg.color.opacity(0.094))
                    .frame(width: 44, height: 44)
                Text(cfg.emoji)
                    .font(.system(size: 22))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(account.name)
                    .font(SikaTheme.Typography.sans(16, weight: .bold))
                    .foregroundStyle(SikaTheme.Color.foreground)
                Text(cfg.label)
                    .font(SikaTheme.Typography.sans(11))
                    .foregroundStyle(SikaTheme.Color.mutedForeground)
            }
            Spacer()
        }
    }

    private var sikaBalanceRow: some View {
        HStack {
            Text("Sika shows")
                .font(SikaTheme.Typography.sans(13))
                .foregroundStyle(SikaTheme.Color.mutedForeground)
            Spacer()
            Text(CurrencyFormatter.format(currentBalance, code: currencyCode))
                .font(SikaTheme.Typography.sans(15, weight: .semibold))
                .foregroundStyle(SikaTheme.Color.foreground)
                .monospacedDigit()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(SikaTheme.Color.muted)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var actualField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Actual current balance")
                .font(SikaTheme.Typography.sans(12, weight: .semibold))
                .foregroundStyle(SikaTheme.Color.foreground)
            HStack(spacing: 6) {
                Text(CurrencyFormatter.symbol(forCode: currencyCode))
                    .font(SikaTheme.Typography.sans(13))
                    .foregroundStyle(SikaTheme.Color.mutedForeground)
                TextField("0.00", text: $actualBalanceText)
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

    private var diffCard: some View {
        let isPositive = diff >= 0
        let color = isPositive ? Color(hex: 0x00D9A3) : Color(hex: 0xF43F5E)
        let absDiff: Decimal = isPositive ? diff : -diff
        let sign = isPositive ? "+" : "−"

        return HStack {
            Text("Adjustment")
                .font(SikaTheme.Typography.sans(12, weight: .semibold))
                .foregroundStyle(color)
            Spacer()
            Text("\(sign)\(CurrencyFormatter.format(absDiff, code: currencyCode))")
                .font(SikaTheme.Typography.sans(13, weight: .bold))
                .foregroundStyle(color)
                .monospacedDigit()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(color.opacity(0.094))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var submitButton: some View {
        Button {
            Task { await commit() }
        } label: {
            HStack {
                if isReconciling { ProgressView().scaleEffect(0.85).tint(darkText) }
                Text(isReconciling ? "Saving…" : "Create adjustment")
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
    }

    private func commit() async {
        guard canSubmit else {
            if diff == 0 {
                toasts.show("Balance already matches", kind: .info)
            }
            return
        }
        isReconciling = true
        defer { isReconciling = false }

        let ok = await appState.reconcileAccountInline(
            accountId: account.id,
            sikaBalance: currentBalance,
            actualBalance: actualBalance
        )
        if ok {
            let formatted = CurrencyFormatter.format(actualBalance, code: currencyCode)
            toasts.show("Reconciled to \(formatted)", kind: .success)
            await onCompleted()
            dismiss()
        } else {
            toasts.show("Failed to reconcile", kind: .error)
        }
    }
}
