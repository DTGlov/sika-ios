import SwiftUI

/// Income Sources section.
/// S1 shipped read-only render with frequency badges + monthly equivalents +
/// total. S2 wires the CRUD form sheet (add / edit / delete) + quick-add
/// templates + AlertCircle inline warning when a fixed-frequency source has
/// no expected_day set.
struct IncomeSourcesSection: View {
    @Environment(AppState.self) private var appState
    @Environment(ToastManager.self) private var toasts

    private let goldColor = Color(hex: 0xD4A017)
    private let warningColor = Color(hex: 0xFBBF24)

    @State private var presentingNewForm: Bool = false
    @State private var editingSource: IncomeSource? = nil
    @State private var templateDefaults: IncomeSourceTemplate? = nil
    @State private var pendingDelete: IncomeSource? = nil

    private var sources: [IncomeSource] { appState.incomeSources }

    var body: some View {
        SettingsCard(
            title: "Income Sources",
            subtitle: "Where your money comes from each month."
        ) {
            VStack(alignment: .leading, spacing: 12) {
                if sources.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 8) {
                        ForEach(sources) { source in
                            row(source)
                        }
                        Divider().padding(.vertical, 4)
                        totalRow
                    }
                }

                IncomeSourceTemplatesStrip(onTemplateTap: openWithTemplate)
                    .padding(.top, sources.isEmpty ? 0 : 4)

                addButton
            }
        }
        .sheet(isPresented: $presentingNewForm) {
            IncomeSourceFormSheet(
                editingSource: nil,
                templateDefaults: templateDefaults,
                accounts: appState.accounts,
                onSaved: {}
            )
            .onDisappear { templateDefaults = nil }
        }
        .sheet(item: $editingSource) { source in
            IncomeSourceFormSheet(
                editingSource: source,
                templateDefaults: nil,
                accounts: appState.accounts,
                onSaved: {}
            )
        }
        .alert(
            "Delete this income source?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            presenting: pendingDelete
        ) { source in
            Button("Cancel", role: .cancel) { pendingDelete = nil }
            Button("Delete", role: .destructive) {
                let target = source
                pendingDelete = nil
                Task { await performDelete(target) }
            }
        } message: { _ in
            Text("This action cannot be undone.")
        }
    }

    // MARK: - Rows

    private var emptyState: some View {
        Text("No income sources yet.")
            .font(SikaTheme.Typography.sans(13))
            .foregroundStyle(SikaTheme.Color.mutedForeground)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
    }

    private func row(_ source: IncomeSource) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 10) {
                if let icon = source.icon, !icon.isEmpty {
                    Text(icon)
                        .font(.system(size: 18))
                        .frame(width: 28, height: 28)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(source.name)
                            .font(SikaTheme.Typography.sans(14, weight: .semibold))
                            .foregroundStyle(SikaTheme.Color.foreground)
                        frequencyBadge(source.frequency)
                    }

                    Text(CurrencyFormatter.format(source.amount, code: appState.currencyCode))
                        .font(SikaTheme.Typography.sans(13))
                        .foregroundStyle(SikaTheme.Color.foreground)

                    if source.frequency == .weekly || source.frequency == .biweekly {
                        Text("≈ \(CurrencyFormatter.format(source.monthlyEquivalent, code: appState.currencyCode))/mo")
                            .font(SikaTheme.Typography.sans(11))
                            .foregroundStyle(SikaTheme.Color.mutedForeground)
                    }
                }

                Spacer()

                HStack(spacing: 0) {
                    iconButton("pencil") { editingSource = source }
                    iconButton("trash") { pendingDelete = source }
                }
            }

            if shouldShowMissingDayWarning(source) {
                missingDayWarning(source)
            }
        }
        .padding(.vertical, 4)
    }

    private func frequencyBadge(_ frequency: IncomeFrequency) -> some View {
        Text(frequency.displayName)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(frequencyColor(frequency))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(frequencyColor(frequency).opacity(0.20))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func frequencyColor(_ frequency: IncomeFrequency) -> Color {
        switch frequency {
        case .monthly:   return Color(hex: 0x00D9A3)
        case .weekly:    return Color(hex: 0x60A5FA)
        case .biweekly:  return Color(hex: 0xFBBF24)
        case .irregular: return Color(hex: 0xA1A1AA)
        }
    }

    private func iconButton(_ name: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: 13))
                .foregroundStyle(SikaTheme.Color.mutedForeground)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func shouldShowMissingDayWarning(_ source: IncomeSource) -> Bool {
        source.frequency.requiresExpectedDay && source.expectedDay == nil
    }

    private func missingDayWarning(_ source: IncomeSource) -> some View {
        Button {
            editingSource = source
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                Text("No reminder day set — tap to add one")
                    .font(SikaTheme.Typography.sans(11, weight: .semibold))
            }
            .foregroundStyle(warningColor)
            .padding(.leading, 38)
        }
        .buttonStyle(.plain)
    }

    private var totalRow: some View {
        HStack {
            Text("Total monthly income")
                .font(SikaTheme.Typography.sans(13, weight: .semibold))
                .foregroundStyle(SikaTheme.Color.foreground)
            Spacer()
            Text(CurrencyFormatter.format(appState.totalMonthlyIncomeComputed, code: appState.currencyCode))
                .font(SikaTheme.Typography.sans(14, weight: .bold))
                .foregroundStyle(goldColor)
                .monospacedDigit()
        }
    }

    private var addButton: some View {
        Button {
            templateDefaults = nil
            presentingNewForm = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                Text("Add source")
            }
            .font(SikaTheme.Typography.sans(13, weight: .semibold))
            .foregroundStyle(goldColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(goldColor.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func openWithTemplate(_ template: IncomeSourceTemplate) {
        templateDefaults = template
        presentingNewForm = true
    }

    private func performDelete(_ source: IncomeSource) async {
        let ok = await appState.deleteIncomeSource(source.id)
        if ok {
            toasts.show("Income source deleted", kind: .success)
        } else {
            toasts.show("Failed to delete", kind: .error)
        }
    }
}
