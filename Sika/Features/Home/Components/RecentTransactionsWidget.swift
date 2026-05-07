import SwiftUI

/// Top 5 transactions from the displayed cycle.
/// Hidden when there are zero transactions in the cycle.
struct RecentTransactionsWidget: View {
    let transactions: [Transaction]
    let categories: [TransactionCategory]
    let currencyCode: String
    let onSeeAllTap: () -> Void

    private var topFive: [Transaction] {
        transactions
            .sorted { lhs, rhs in
                if lhs.transactionDate != rhs.transactionDate {
                    return lhs.transactionDate > rhs.transactionDate
                }
                let l = lhs.createdAt ?? Date.distantPast
                let r = rhs.createdAt ?? Date.distantPast
                return l > r
            }
            .prefix(5)
            .map { $0 }
    }

    var body: some View {
        if topFive.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: SikaTheme.Spacing.sm) {
                HStack {
                    Text("RECENT")
                        .font(SikaTheme.Typography.sans(11, weight: .semibold))
                        .foregroundStyle(SikaTheme.Color.mutedForeground)
                        .tracking(1)
                    Spacer()
                    Button(action: onSeeAllTap) {
                        Text("See all")
                            .font(SikaTheme.Typography.sans(13, weight: .semibold))
                            .foregroundStyle(SikaTheme.Color.sikaAccent)
                    }
                    .buttonStyle(.plain)
                }

                VStack(spacing: SikaTheme.Spacing.xs) {
                    ForEach(topFive) { tx in
                        RecentTransactionRow(
                            transaction: tx,
                            categories: categories,
                            currencyCode: currencyCode
                        )
                    }
                }
            }
            .padding(.horizontal, SikaTheme.Spacing.lg)
        }
    }
}

private struct RecentTransactionRow: View {
    let transaction: Transaction
    let categories: [TransactionCategory]
    let currencyCode: String

    private static let inputFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        return f
    }()

    private static let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private var category: TransactionCategory? {
        guard let categoryId = transaction.categoryId else { return nil }
        return categories.first(where: { $0.id == categoryId })
    }

    private var emoji: String {
        IconResolver.resolve(category?.icon)
    }

    private var label: String {
        category?.name ?? typeLabel
    }

    private var typeLabel: String {
        switch transaction.type {
        case .expense: return "Expense"
        case .income: return "Income"
        case .transfer: return "Transfer"
        case .adjustment: return "Adjustment"
        }
    }

    private var dateText: String {
        guard let date = Self.inputFormatter.date(from: transaction.transactionDate) else {
            return transaction.transactionDate
        }
        return Self.displayFormatter.string(from: date)
    }

    private var subtitle: String {
        if let note = transaction.note, !note.isEmpty {
            return note
        }
        return dateText
    }

    private var signedAmountText: String {
        let prefix: String
        switch transaction.type {
        case .income: prefix = "+"
        case .expense: prefix = "-"
        case .transfer, .adjustment: prefix = ""
        }
        return "\(prefix)\(CurrencyFormatter.compact(transaction.amount, code: currencyCode))"
    }

    private var amountColor: Color {
        switch transaction.type {
        case .income: return SikaTheme.Color.sikaSuccess
        default: return SikaTheme.Color.foreground
        }
    }

    var body: some View {
        HStack(spacing: SikaTheme.Spacing.md) {
            Text(emoji)
                .font(.system(size: 18))
                .frame(width: 36, height: 36)
                .background(Circle().fill(SikaTheme.Color.muted))

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(SikaTheme.Typography.sans(15, weight: .semibold))
                    .foregroundStyle(SikaTheme.Color.foreground)
                Text(subtitle)
                    .font(SikaTheme.Typography.sans(12))
                    .foregroundStyle(SikaTheme.Color.mutedForeground)
                    .lineLimit(1)
            }

            Spacer()

            Text(signedAmountText)
                .font(SikaTheme.Typography.mono(14, weight: .semibold))
                .foregroundStyle(amountColor)
        }
        .padding(SikaTheme.Spacing.sm)
        .background(SikaTheme.Color.card)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
