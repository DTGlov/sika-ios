import SwiftUI

/// Total Monthly Income echo + Budget Month + Budget Split.
/// Single Save button covers all 4 fields together. Disabled when sum != 100
/// or when fields are unchanged from profile.
struct BudgetConfigForm: View {
    @Environment(AppState.self) private var appState
    @Environment(ToastManager.self) private var toasts

    @State private var cycleStartDay: Int = 1
    @State private var needsPercent: Int = 50
    @State private var wantsPercent: Int = 30
    @State private var savingsPercent: Int = 20
    @State private var isSaving = false

    private let goldColor = Color(hex: 0xD4A017)
    private let darkText = Color(hex: 0x0E1A2E)
    private let needsColor = Color(hex: 0x00D9A3)
    private let wantsColor = Color(hex: 0xFBBF24)
    private let savingsColor = Color(hex: 0x60A5FA)

    private var profile: Profile? {
        if case .authenticated(let p) = appState.flow { return p }
        return nil
    }

    private var sumIs100: Bool {
        needsPercent + wantsPercent + savingsPercent == 100
    }

    private var isDirty: Bool {
        guard let profile else { return false }
        let pNeeds = Int((NSDecimalNumber(decimal: profile.needsPercentValue) as Decimal as NSDecimalNumber).intValue)
        let pWants = Int((NSDecimalNumber(decimal: profile.wantsPercentValue) as Decimal as NSDecimalNumber).intValue)
        let pSavings = Int((NSDecimalNumber(decimal: profile.savingsPercentValue) as Decimal as NSDecimalNumber).intValue)
        let pCycle = profile.cycleStartDay ?? 1
        return cycleStartDay != pCycle
            || needsPercent != pNeeds
            || wantsPercent != pWants
            || savingsPercent != pSavings
    }

    private var canSave: Bool {
        sumIs100 && isDirty && !isSaving
    }

    private var totalIncome: Decimal {
        appState.totalMonthlyIncomeComputed
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            totalIncomeCard
            budgetMonthCard
            budgetSplitCard
            saveButton
        }
        .onAppear { primeFromProfile() }
    }

    // MARK: - Cards

    private var totalIncomeCard: some View {
        SettingsCard(
            title: "Total Monthly Income",
            subtitle: "Sum of your active income sources."
        ) {
            HStack {
                Text(CurrencyFormatter.format(totalIncome, code: appState.currencyCode))
                    .font(SikaTheme.Typography.sans(20, weight: .bold))
                    .foregroundStyle(goldColor)
                    .monospacedDigit()
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(SikaTheme.Color.muted)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var budgetMonthCard: some View {
        SettingsCard(
            title: "Budget Month",
            subtitle: "The day your budget cycle starts each month (1–28)."
        ) {
            HStack(spacing: 12) {
                Stepper(value: $cycleStartDay, in: 1...28) {
                    HStack {
                        Text("Day")
                            .font(SikaTheme.Typography.sans(13))
                            .foregroundStyle(SikaTheme.Color.mutedForeground)
                        Text("\(cycleStartDay)")
                            .font(SikaTheme.Typography.sans(15, weight: .semibold))
                            .foregroundStyle(SikaTheme.Color.foreground)
                            .monospacedDigit()
                    }
                }
            }
            Text("Tip: many people use the day they get paid.")
                .font(SikaTheme.Typography.sans(11))
                .foregroundStyle(SikaTheme.Color.mutedForeground)
        }
    }

    private var budgetSplitCard: some View {
        SettingsCard(
            title: "Budget Split",
            subtitle: "How your income divides across Needs / Wants / Savings (must sum to 100%)."
        ) {
            VStack(spacing: 10) {
                splitInput(label: "Needs",   color: needsColor,   value: $needsPercent)
                splitInput(label: "Wants",   color: wantsColor,   value: $wantsPercent)
                splitInput(label: "Savings", color: savingsColor, value: $savingsPercent)

                if !sumIs100 {
                    Text("Total: \(needsPercent + wantsPercent + savingsPercent)% — must equal 100%")
                        .font(SikaTheme.Typography.sans(11, weight: .semibold))
                        .foregroundStyle(Color(hex: 0xF43F5E))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func splitInput(label: String, color: Color, value: Binding<Int>) -> some View {
        let pct = Decimal(value.wrappedValue)
        let derivedAmount = totalIncome * pct / 100
        return HStack(spacing: 12) {
            Text(label)
                .font(SikaTheme.Typography.sans(13, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 70, alignment: .leading)

            Stepper(value: value, in: 0...100) {
                HStack {
                    Text("\(value.wrappedValue)%")
                        .font(SikaTheme.Typography.sans(14, weight: .semibold))
                        .foregroundStyle(SikaTheme.Color.foreground)
                        .monospacedDigit()
                        .frame(width: 50, alignment: .leading)
                    Text(CurrencyFormatter.format(derivedAmount, code: appState.currencyCode))
                        .font(SikaTheme.Typography.sans(11))
                        .foregroundStyle(SikaTheme.Color.mutedForeground)
                }
            }
        }
    }

    private var saveButton: some View {
        Button {
            Task { await save() }
        } label: {
            HStack {
                if isSaving {
                    ProgressView().scaleEffect(0.85).tint(darkText)
                }
                Text("Save changes")
                    .font(SikaTheme.Typography.sans(15, weight: .semibold))
                    .foregroundStyle(canSave ? darkText : SikaTheme.Color.mutedForeground)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(canSave ? goldColor : SikaTheme.Color.muted)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(!canSave)
    }

    // MARK: - Helpers

    private func primeFromProfile() {
        guard let profile else { return }
        cycleStartDay = profile.cycleStartDay ?? 1
        needsPercent = decimalToInt(profile.needsPercentValue)
        wantsPercent = decimalToInt(profile.wantsPercentValue)
        savingsPercent = decimalToInt(profile.savingsPercentValue)
    }

    private func decimalToInt(_ d: Decimal) -> Int {
        NSDecimalNumber(decimal: d).intValue
    }

    private func save() async {
        guard canSave else { return }
        isSaving = true
        defer { isSaving = false }

        let ok = await appState.saveBudgetConfig(
            cycleStartDay: cycleStartDay,
            needsPercent: Decimal(needsPercent),
            wantsPercent: Decimal(wantsPercent),
            savingsPercent: Decimal(savingsPercent)
        )
        if ok {
            toasts.show("Settings saved", kind: .success)
        } else {
            toasts.show("Failed to save", kind: .error)
        }
    }
}
