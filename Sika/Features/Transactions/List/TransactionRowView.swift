import SwiftUI

/// Single row in the transactions list. Mirror of web's TransactionItem.
/// Per-type rendering rules: expense (foreground), income (gold +),
/// transfer (muted, "account → toAccount"), adjustment (signed, gold/rose).
struct TransactionRowView: View {
    let row: TransactionListRow
    let currencyCode: String
    /// Caller is responsible for the actual delete; this view only confirms.
    let onDelete: () async -> Void
    /// Caller opens the wizard in edit mode. Optional so existing call sites
    /// (e.g. previews) don't need to wire one — they get a no-op.
    var onEdit: (() -> Void)? = nil

    @State private var showDeleteAlert = false

    private let goldColor = Color(hex: 0xD4A017)
    private let roseColor = Color(hex: 0xF43F5E)
    private let blueColor = Color(hex: 0x60A5FA)
    private let greenColor = Color(hex: 0x00D9A3)

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            iconSquare

            VStack(alignment: .leading, spacing: 2) {
                titleRow
                subtitleRow
                dateLabel
            }

            Spacer(minLength: 8)

            amountLabel
            actionMenu
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .alert("Delete this transaction?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task { await onDelete() }
            }
        } message: {
            Text("This will permanently remove \"\(transactionLabel)\" (\(formattedAmount)) from your records. This can't be undone.")
        }
    }

    // MARK: - Icon

    private var iconSquare: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(iconBackground)
                .frame(width: 40, height: 40)

            if row.type == .adjustment {
                Image(systemName: "scalemass")
                    .font(.system(size: 18))
                    .foregroundStyle(SikaTheme.Color.mutedForeground)
            } else {
                Text(IconResolver.resolve(row.category?.icon))
                    .font(.system(size: 18))
            }
        }
    }

    private var iconBackground: Color {
        if row.type == .adjustment {
            return SikaTheme.Color.mutedForeground.opacity(0.10)
        }
        if let bucketName = row.category?.bucket?.name.lowercased() {
            switch bucketName {
            case "needs":   return SikaTheme.Color.bucketNeeds.opacity(0.13)
            case "wants":   return SikaTheme.Color.bucketWants.opacity(0.13)
            case "savings": return SikaTheme.Color.bucketSavings.opacity(0.13)
            default: break
            }
        }
        return SikaTheme.Color.muted
    }

    // MARK: - Title row

    private var titleRow: some View {
        HStack(spacing: 6) {
            Text(titleText)
                .font(SikaTheme.Typography.sans(14, weight: .semibold))
                .foregroundStyle(SikaTheme.Color.foreground)
                .lineLimit(1)
                .truncationMode(.tail)

            if row.type == .adjustment {
                Text("adj")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(SikaTheme.Color.mutedForeground)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(SikaTheme.Color.muted)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
    }

    private var titleText: String {
        switch row.type {
        case .transfer:
            let from = row.account?.name ?? "?"
            let to = row.toAccount?.name ?? "?"
            return "\(from) → \(to)"
        case .adjustment:
            return "Balance adjustment"
        case .expense, .income:
            return row.category?.name ?? "Uncategorized"
        }
    }

    // MARK: - Subtitle row (chips + account name + note)

    @ViewBuilder
    private var subtitleRow: some View {
        let pieces = subtitlePieces
        if !pieces.isEmpty {
            HStack(spacing: 6) {
                ForEach(0..<pieces.count, id: \.self) { i in
                    pieces[i]
                }
            }
        }
    }

    private var subtitlePieces: [AnyView] {
        var out: [AnyView] = []
        if row.type != .transfer, let accountName = row.account?.name {
            out.append(AnyView(
                Text(accountName)
                    .font(SikaTheme.Typography.sans(11))
                    .foregroundStyle(SikaTheme.Color.mutedForeground.opacity(0.8))
                    .lineLimit(1)
                    .truncationMode(.tail)
            ))
        }
        if row.generatedFromRecurring != nil {
            out.append(AnyView(pillChip(
                text: "Auto",
                bg: blueColor.opacity(0.12),
                fg: blueColor
            )))
        }
        if row.paidFromGoalId != nil {
            out.append(AnyView(pillChip(
                text: "🎯 From fund",
                bg: greenColor.opacity(0.12),
                fg: goldColor
            )))
        }
        if let note = row.note, !note.isEmpty {
            out.append(AnyView(
                Text(note)
                    .font(SikaTheme.Typography.sans(11))
                    .foregroundStyle(SikaTheme.Color.mutedForeground)
                    .lineLimit(1)
                    .truncationMode(.tail)
            ))
        }
        return out
    }

    private func pillChip(text: String, bg: Color, fg: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(fg)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(bg)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Date label

    private var dateLabel: some View {
        Text(formatTransactionDate(row.transactionDate))
            .font(SikaTheme.Typography.sans(11))
            .foregroundStyle(SikaTheme.Color.mutedForeground)
    }

    /// Today / Yesterday / weekday for older dates.
    /// Matches web's formatTransactionDate.
    private func formatTransactionDate(_ dateStr: String) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        guard let date = f.date(from: dateStr) else { return dateStr }

        let cal = Calendar.current
        if cal.isDateInToday(date)     { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }

        let weekday = DateFormatter()
        weekday.dateFormat = "EEEE"
        return weekday.string(from: date)
    }

    // MARK: - Amount

    private var amountLabel: some View {
        Text(amountText)
            .font(SikaTheme.Typography.sans(14, weight: .semibold))
            .foregroundStyle(amountColor)
            .monospacedDigit()
    }

    private var amountText: String {
        let abs = NSDecimalNumber(decimal: row.amount).doubleValue.magnitude
        let absDecimal = Decimal(abs)
        let formatted = CurrencyFormatter.format(absDecimal, code: currencyCode)
        switch row.type {
        case .income:
            return "+\(formatted)"
        case .transfer:
            return formatted
        case .adjustment:
            return row.amount >= 0 ? "+\(formatted)" : "-\(formatted)"
        case .expense:
            return "-\(formatted)"
        }
    }

    private var amountColor: Color {
        switch row.type {
        case .income:
            return goldColor
        case .transfer:
            return SikaTheme.Color.mutedForeground
        case .adjustment:
            return row.amount >= 0 ? goldColor : roseColor
        case .expense:
            return SikaTheme.Color.foreground
        }
    }

    private var formattedAmount: String {
        let abs = NSDecimalNumber(decimal: row.amount).doubleValue.magnitude
        return CurrencyFormatter.format(Decimal(abs), code: currencyCode)
    }

    // MARK: - Action menu (3-dot)

    private var actionMenu: some View {
        Menu {
            // T3 — adjustments cannot be edited. Editing them retroactively
            // changes the meaning of every transaction logged after the
            // original adjustment. To fix a bad reconcile: delete + reconcile
            // again.
            if row.type != .adjustment {
                Button {
                    onEdit?()
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
            }

            Button(role: .destructive) {
                showDeleteAlert = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 16))
                .foregroundStyle(SikaTheme.Color.mutedForeground)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
    }

    // MARK: - Computed

    private var transactionLabel: String {
        if let note = row.note, !note.isEmpty { return note }
        switch row.type {
        case .transfer:
            return "\(row.account?.name ?? "?") → \(row.toAccount?.name ?? "?")"
        case .adjustment:
            return "Balance adjustment"
        case .expense, .income:
            return row.category?.name ?? "this transaction"
        }
    }
}
