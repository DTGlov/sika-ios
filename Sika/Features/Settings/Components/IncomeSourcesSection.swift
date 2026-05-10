import SwiftUI

/// Read-only Income Sources section. S2 wires the CRUD form sheet.
/// For S1: list visible with frequency badges + monthly equivalents + total.
/// Edit / Trash icons render but tap shows "Coming in v2" toast. Add button is disabled.
struct IncomeSourcesSection: View {
    @Environment(AppState.self) private var appState
    @Environment(ToastManager.self) private var toasts

    private let goldColor = Color(hex: 0xD4A017)

    private var sources: [IncomeSource] { appState.incomeSources }

    var body: some View {
        SettingsCard(
            title: "Income Sources",
            subtitle: "Where your money comes from each month."
        ) {
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
                addButton
                    .padding(.top, 8)
            }
        }
    }

    private var emptyState: some View {
        Text("No income sources yet.")
            .font(SikaTheme.Typography.sans(13))
            .foregroundStyle(SikaTheme.Color.mutedForeground)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
    }

    private func row(_ source: IncomeSource) -> some View {
        HStack(alignment: .top, spacing: 8) {
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

                if source.frequency != .monthly && source.frequency != .irregular {
                    Text("≈ \(CurrencyFormatter.format(source.monthlyEquivalent, code: appState.currencyCode))/mo")
                        .font(SikaTheme.Typography.sans(11))
                        .foregroundStyle(SikaTheme.Color.mutedForeground)
                }
            }

            Spacer()

            HStack(spacing: 0) {
                disabledIcon("pencil")
                disabledIcon("trash")
            }
            .opacity(0.4)
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

    private func disabledIcon(_ name: String) -> some View {
        Button {
            toasts.show("Income source editing coming soon", kind: .info)
        } label: {
            Image(systemName: name)
                .font(.system(size: 13))
                .foregroundStyle(SikaTheme.Color.mutedForeground)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
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
            toasts.show("Adding income sources coming soon", kind: .info)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                Text("Add source")
            }
            .font(SikaTheme.Typography.sans(13, weight: .semibold))
            .foregroundStyle(SikaTheme.Color.mutedForeground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(SikaTheme.Color.muted)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .opacity(0.6)
    }
}

