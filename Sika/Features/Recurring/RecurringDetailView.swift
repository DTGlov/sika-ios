import SwiftUI

/// Per-recurring detail page (NavigationStack push). Mirror of /recurring/[id]
/// on web. Shows the current period plus Log/Skip CTAs for non-auto-log rows.
struct RecurringDetailView: View {
    let recurring: RecurringTransaction

    @Environment(AppState.self) private var appState
    @Environment(ToastManager.self) private var toasts
    @Environment(\.dismiss) private var dismiss

    private let goldColor = Color(hex: 0xD4A017)
    private let darkText = Color(hex: 0x0E1A2E)
    private let greenColor = Color(hex: 0x00D9A3)
    private let redColor = Color(hex: 0xF43F5E)

    private var period: (start: String, end: String)? {
        RecurringDateMath.currentInstancePeriod(recurring)
    }

    private var nextDueDateStr: String? {
        guard let date = RecurringDateMath.nextDueDate(for: recurring, from: Date()) else { return nil }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        return f.string(from: date)
    }

    private var isHandled: Bool {
        RecurringDateMath.isHandledThisInstance(recurring)
    }

    private var showLogSkipCTAs: Bool {
        !recurring.autoLog && !isHandled && !recurring.isPaused
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                summaryCard
                periodSection
                if showLogSkipCTAs {
                    ctaButtons
                } else {
                    statusCard
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(SikaTheme.Color.background)
        .navigationTitle(displayName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var displayName: String {
        if let note = recurring.note, !note.isEmpty { return note }
        return recurring.category?.name ?? "Recurring"
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayName)
                        .font(SikaTheme.Typography.sans(20, weight: .bold))
                        .foregroundStyle(SikaTheme.Color.foreground)
                    Text(metaLine)
                        .font(SikaTheme.Typography.sans(12))
                        .foregroundStyle(SikaTheme.Color.mutedForeground)
                }
                Spacer()
                Text(CurrencyFormatter.format(recurring.amount, code: appState.currencyCode))
                    .font(SikaTheme.Typography.sans(20, weight: .bold))
                    .foregroundStyle(recurring.type == .income ? greenColor : redColor)
                    .monospacedDigit()
            }

            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.system(size: 12))
                    .foregroundStyle(SikaTheme.Color.mutedForeground)
                Text(RecurringDateMath.formatScheduleSummary(recurring))
                    .font(SikaTheme.Typography.sans(13))
                    .foregroundStyle(SikaTheme.Color.mutedForeground)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SikaTheme.Color.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(SikaTheme.Color.border, lineWidth: 1)
        )
    }

    private var metaLine: String {
        var parts: [String] = []
        if let acc = recurring.account?.name { parts.append(acc) }
        if let cat = recurring.category?.name { parts.append(cat) }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private var periodSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("THIS PERIOD")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.5)
                .foregroundStyle(SikaTheme.Color.mutedForeground)

            if let period {
                Text("\(prettyDate(period.start)) – \(prettyDate(period.end))")
                    .font(SikaTheme.Typography.sans(14, weight: .semibold))
                    .foregroundStyle(SikaTheme.Color.foreground)
            } else if let next = nextDueDateStr {
                Text("Next: \(prettyDate(next))")
                    .font(SikaTheme.Typography.sans(14, weight: .semibold))
                    .foregroundStyle(SikaTheme.Color.foreground)
            } else {
                Text("No upcoming occurrences.")
                    .font(SikaTheme.Typography.sans(14))
                    .foregroundStyle(SikaTheme.Color.mutedForeground)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SikaTheme.Color.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(SikaTheme.Color.border, lineWidth: 1)
        )
    }

    private var ctaButtons: some View {
        VStack(spacing: 8) {
            Button {
                Task { await logNow() }
            } label: {
                Text("Log this instance now")
                    .font(SikaTheme.Typography.sans(15, weight: .semibold))
                    .foregroundStyle(darkText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(goldColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)

            Button {
                Task { await skip() }
            } label: {
                Text("Skip this period")
                    .font(SikaTheme.Typography.sans(15, weight: .semibold))
                    .foregroundStyle(SikaTheme.Color.mutedForeground)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(SikaTheme.Color.card)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(SikaTheme.Color.border, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(statusText)
                .font(SikaTheme.Typography.sans(13))
                .foregroundStyle(SikaTheme.Color.mutedForeground)
                .multilineTextAlignment(.leading)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SikaTheme.Color.muted)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var statusText: String {
        if recurring.isPaused { return "This recurring is paused. Resume it from the list to start tracking again." }
        if isHandled { return "This period is already logged. Nothing to do." }
        return "Auto-log is on — Sika will log this for you each period."
    }

    private func prettyDate(_ str: String) -> String {
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = .current
        guard let date = parser.date(from: str) else { return str }
        let display = DateFormatter()
        display.dateFormat = "MMM d, yyyy"
        return display.string(from: date)
    }

    // MARK: - Actions

    private func logNow() async {
        guard let due = nextDueDateStr else { return }
        let ok = await appState.logRecurringInstanceNow(recurring, dueDate: due)
        if ok {
            toasts.show("Logged for this period", kind: .success)
            dismiss()
        } else {
            toasts.show("Couldn't log it. Try again.", kind: .error)
        }
    }

    private func skip() async {
        guard let due = nextDueDateStr else { return }
        let ok = await appState.skipRecurringPeriod(recurring, dueDate: due)
        if ok {
            toasts.show("Skipped", kind: .success)
            dismiss()
        } else {
            toasts.show("Couldn't skip. Try again.", kind: .error)
        }
    }
}
