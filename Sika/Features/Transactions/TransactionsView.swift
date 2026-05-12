import SwiftUI

/// Phase T1 — read-only Transactions tab.
/// Period tabs + search + filter sheet + day-grouped list + pagination.
/// FAB lives on AuthenticatedRootView's overlay (already wired); this view
/// doesn't render the FAB itself.
struct TransactionsView: View {
    @Environment(AppState.self) private var appState

    @State private var search: String = ""
    @State private var showFilters: Bool = false
    @State private var editingTransaction: Transaction? = nil

    private let goldColor = Color(hex: 0xD4A017)
    private let darkText = Color(hex: 0x0E1A2E)

    var body: some View {
        @Bindable var appStateBindable = appState

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                PeriodTabsView(selected: $appStateBindable.transactionFilters.period)

                HStack(spacing: 8) {
                    TransactionSearchField(text: $search)
                    filtersButton
                }

                if appState.transactionFilters.activeFilterCount > 0 || !search.isEmpty {
                    inlineClearButton
                }

                listContent
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 100) // clear FAB
        }
        .background(SikaTheme.Color.background)
        .refreshable {
            await appState.loadFirstTransactionsPage()
        }
        .sheet(isPresented: $showFilters) {
            TransactionFilterSheet(
                filters: $appStateBindable.transactionFilters,
                accounts: appState.accounts,
                categories: appState.categories,
                budgetBuckets: appState.budgetBuckets
            )
        }
        .sheet(item: $editingTransaction) { txn in
            AddTransactionWizardView(
                accounts: appState.accounts,
                categories: appState.categories,
                editingTransaction: txn
            )
        }
        .task {
            // Initial load on first appearance.
            if appState.transactionsList.isEmpty && !appState.transactionsLoading {
                await appState.loadFirstTransactionsPage()
            }
        }
        .onChange(of: appState.transactionFilters) { _, _ in
            Task { await appState.loadFirstTransactionsPage() }
        }
    }

    // MARK: - Header

    private var header: some View {
        Text("Transactions")
            .font(SikaTheme.Typography.sans(28, weight: .bold))
            .foregroundStyle(SikaTheme.Color.foreground)
    }

    // MARK: - Filters button

    private var filtersButton: some View {
        Button {
            showFilters = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 14))
                Text("Filters")
                    .font(SikaTheme.Typography.sans(13, weight: .semibold))
                if appState.transactionFilters.activeFilterCount > 0 {
                    Text("\(appState.transactionFilters.activeFilterCount)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(darkText)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(goldColor)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .foregroundStyle(
                appState.transactionFilters.activeFilterCount > 0
                    ? goldColor
                    : SikaTheme.Color.mutedForeground
            )
            .background(
                appState.transactionFilters.activeFilterCount > 0
                    ? goldColor.opacity(0.12)
                    : SikaTheme.Color.card
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        appState.transactionFilters.activeFilterCount > 0
                            ? goldColor
                            : SikaTheme.Color.border,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var inlineClearButton: some View {
        Button {
            @Bindable var appStateBindable = appState
            appStateBindable.transactionFilters.clearAll()
            search = ""
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 11))
                Text("Clear filters")
                    .font(SikaTheme.Typography.sans(11))
            }
            .foregroundStyle(goldColor)
        }
        .buttonStyle(.plain)
    }

    // MARK: - List content

    @ViewBuilder
    private var listContent: some View {
        if appState.transactionsLoading && appState.transactionsList.isEmpty {
            skeleton
        } else if filteredAndGrouped.isEmpty {
            emptyState
        } else {
            LazyVStack(spacing: 16) {
                ForEach(filteredAndGrouped, id: \.0) { dateStr, rows in
                    TransactionDayCard(
                        dateStr: dateStr,
                        rows: rows,
                        currencyCode: appState.currencyCode,
                        onDelete: { id in
                            _ = await appState.deleteTransactionFromList(id)
                        },
                        onEdit: { row in
                            editingTransaction = TransactionsView.transaction(from: row)
                        }
                    )
                }

                if appState.transactionsHasMore {
                    loadMoreButton
                }
            }
        }
    }

    private var skeleton: some View {
        VStack(spacing: 12) {
            ForEach(0..<6, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 16)
                    .fill(SikaTheme.Color.muted)
                    .frame(height: 76)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 32))
                .foregroundStyle(SikaTheme.Color.mutedForeground.opacity(0.6))
            Text("No transactions match your filters.")
                .font(SikaTheme.Typography.sans(13))
                .foregroundStyle(SikaTheme.Color.mutedForeground)
                .multilineTextAlignment(.center)
            if appState.transactionFilters.activeFilterCount > 0 || !search.isEmpty {
                Button {
                    @Bindable var appStateBindable = appState
                    appStateBindable.transactionFilters.clearAll()
                    search = ""
                } label: {
                    Text("Clear filters")
                        .font(SikaTheme.Typography.sans(12, weight: .semibold))
                        .foregroundStyle(goldColor)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private var loadMoreButton: some View {
        Button {
            Task { await appState.loadMoreTransactions() }
        } label: {
            HStack(spacing: 6) {
                if appState.transactionsLoadingMore {
                    ProgressView().scaleEffect(0.8)
                } else {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12))
                }
                Text(appState.transactionsLoadingMore ? "Loading…" : "Load more")
                    .font(SikaTheme.Typography.sans(13, weight: .semibold))
            }
            .foregroundStyle(SikaTheme.Color.mutedForeground)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(SikaTheme.Color.card)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(SikaTheme.Color.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    // MARK: - Edit-mode bridging

    /// Build a `Transaction` from the joined T1 row. The wizard's edit branch
    /// reads only the unjoined fields (type/amount/account ids/category/note/
    /// date/paid-from-goal) — all present on the row. Server timestamps
    /// (createdAt) are preserved; updatedAt is left nil and will be filled
    /// by the persisted row when the edit save resolves.
    static func transaction(from row: TransactionListRow) -> Transaction {
        Transaction(
            id: row.id,
            userId: row.userId,
            type: row.type,
            amount: row.amount,
            accountId: row.accountId,
            toAccountId: row.toAccountId,
            categoryId: row.categoryId,
            goalId: row.goalId,
            paidFromGoalId: row.paidFromGoalId,
            transactionDate: row.transactionDate,
            note: row.note,
            softDeleted: false,
            generatedFromRecurring: row.generatedFromRecurring,
            createdAt: row.createdAt,
            updatedAt: nil
        )
    }

    // MARK: - Filtering + grouping

    /// Apply client-side search + bucket filters, then group by transaction_date.
    /// Day order respects the user's date sort direction.
    private var filteredAndGrouped: [(String, [TransactionListRow])] {
        let q = search.trimmingCharacters(in: .whitespaces).lowercased()
        let qNum: Decimal? = q.isEmpty ? nil : Decimal(string: q)
        let bucketName = appState.transactionFilters.bucket?.rawValue.lowercased()

        let filtered: [TransactionListRow] = appState.transactionsList.filter { row in
            if !q.isEmpty {
                let matchNote = (row.note ?? "").lowercased().contains(q)
                let matchCat  = (row.category?.name ?? "").lowercased().contains(q)
                let matchAcc  = (row.account?.name ?? "").lowercased().contains(q)
                    || (row.toAccount?.name ?? "").lowercased().contains(q)
                let matchAmt: Bool = {
                    guard let qNum else { return false }
                    let absA = abs(NSDecimalNumber(decimal: row.amount).doubleValue)
                    let absQ = abs(NSDecimalNumber(decimal: qNum).doubleValue)
                    return absA == absQ
                }()
                if !matchNote && !matchCat && !matchAcc && !matchAmt { return false }
            }
            if let bucketName {
                if (row.category?.bucket?.name.lowercased() ?? "") != bucketName {
                    return false
                }
            }
            return true
        }

        var grouped: [String: [TransactionListRow]] = [:]
        for row in filtered {
            grouped[row.transactionDate, default: []].append(row)
        }

        let isAsc = appState.transactionFilters.sort == .dateAsc
        return grouped.sorted { isAsc ? $0.key < $1.key : $0.key > $1.key }
            .map { ($0.key, $0.value) }
    }
}
