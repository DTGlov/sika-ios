import SwiftUI

/// Phase Accounts T1 — Accounts tab orchestrator.
/// Wraps in NavigationStack at the call site (AuthenticatedRootView) so any
/// future detail page push works.
struct AccountsView: View {
    @Environment(AppState.self) private var appState
    @Environment(ToastManager.self) private var toasts

    @State private var showFormSheet: Bool = false
    @State private var editingAccount: Account? = nil

    @State private var showReconcileSheet: Bool = false
    @State private var reconcileTarget: Account? = nil

    @State private var showDeleteSheet: Bool = false
    @State private var deletingAccount: Account? = nil
    @State private var deletingTransactionCount: Int = 0

    @State private var showSimpleDeleteAlert: Bool = false

    private let goldColor = Color(hex: 0xD4A017)
    private let darkText = Color(hex: 0x0E1A2E)

    private var activeAccounts: [Account] {
        appState.accounts
            .filter { $0.isActive != false }
            .sorted { ($0.sortOrder ?? Int.max) < ($1.sortOrder ?? Int.max) }
    }

    private var allOpeningBalancesZero: Bool {
        let actives = activeAccounts
        guard !actives.isEmpty else { return false }
        return actives.allSatisfy { ($0.openingBalance ?? 0) == 0 }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                totalBalanceCard

                if allOpeningBalancesZero {
                    HintCard(
                        hintId: .accountsIntro,
                        title: "Set your starting balances",
                        message: "Edit each account and set its current balance — Sika needs this to track running totals correctly."
                    )
                }

                HintCard(
                    hintId: .accountsReconcileReminder,
                    title: "Reconcile when life happens",
                    message: "If the actual balance in your account doesn't match Sika's number, tap ⚖️ to fix it with an adjustment."
                )

                if activeAccounts.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(activeAccounts) { account in
                            AccountRowView(
                                account: account,
                                balance: AccountBalanceEngine.balance(for: account, in: appState.accountsBalances),
                                currencyCode: appState.currencyCode,
                                onReconcile: {
                                    reconcileTarget = account
                                    showReconcileSheet = true
                                },
                                onEdit: {
                                    editingAccount = account
                                    showFormSheet = true
                                },
                                onDelete: {
                                    Task { await beginDelete(account: account) }
                                }
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 100)
        }
        .background(SikaTheme.Color.background)
        .sheet(isPresented: $showFormSheet) {
            if let acc = editingAccount {
                AccountFormSheet(
                    editingAccount: acc,
                    currentBalance: AccountBalanceEngine.balance(for: acc, in: appState.accountsBalances),
                    currencyCode: appState.currencyCode,
                    onSaved: { /* AppState handles the reload */ }
                )
            } else {
                AccountFormSheet(
                    editingAccount: nil,
                    currentBalance: 0,
                    currencyCode: appState.currencyCode,
                    onSaved: { /* AppState handles the reload */ }
                )
            }
        }
        .sheet(isPresented: $showReconcileSheet) {
            if let acc = reconcileTarget {
                ReconcileAccountSheet(
                    account: acc,
                    currentBalance: AccountBalanceEngine.balance(for: acc, in: appState.accountsBalances),
                    currencyCode: appState.currencyCode,
                    onCompleted: { /* AppState reloads balances */ }
                )
            }
        }
        .sheet(isPresented: $showDeleteSheet) {
            if let acc = deletingAccount {
                DeleteAccountSheet(
                    account: acc,
                    transactionCount: deletingTransactionCount,
                    candidates: activeAccounts.filter { $0.id != acc.id },
                    onDeleted: { /* AppState handles the reload */ }
                )
            }
        }
        .alert(
            "Delete \(deletingAccount?.name ?? "this account")?",
            isPresented: $showSimpleDeleteAlert
        ) {
            Button("Cancel", role: .cancel) { deletingAccount = nil }
            Button("Delete", role: .destructive) {
                Task { await commitSimpleDelete() }
            }
        } message: {
            Text("This account has no transactions. This can't be undone.")
        }
        .task {
            await appState.recomputeAccountBalances()
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            Text("Accounts")
                .font(SikaTheme.Typography.sans(28, weight: .bold))
                .foregroundStyle(SikaTheme.Color.foreground)
            Spacer()
            Button {
                editingAccount = nil
                showFormSheet = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                    Text("Add")
                        .font(SikaTheme.Typography.sans(13, weight: .semibold))
                }
                .foregroundStyle(darkText)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(goldColor)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Total balance card

    private var totalBalanceCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("TOTAL BALANCE")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.5)
                .foregroundStyle(SikaTheme.Color.mutedForeground)
            Text(CurrencyFormatter.format(appState.totalActiveBalance, code: appState.currencyCode))
                .font(SikaTheme.Typography.sans(28, weight: .bold))
                .foregroundStyle(SikaTheme.Color.foreground)
                .monospacedDigit()
            Text("The money currently in your accounts.")
                .font(SikaTheme.Typography.sans(11))
                .foregroundStyle(SikaTheme.Color.mutedForeground)
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

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("No accounts yet. Tap \"Add\" to create one.")
                .font(SikaTheme.Typography.sans(13))
                .foregroundStyle(SikaTheme.Color.mutedForeground)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    // MARK: - Delete flow

    private func beginDelete(account: Account) async {
        let count = await appState.countTransactionsForAccount(account.id)
        deletingAccount = account
        deletingTransactionCount = count
        if count > 0 {
            showDeleteSheet = true
        } else {
            showSimpleDeleteAlert = true
        }
    }

    private func commitSimpleDelete() async {
        guard let acc = deletingAccount else { return }
        let ok = await appState.deleteAccountWithReassign(acc.id, reassignTo: nil)
        if ok {
            toasts.show("Account deleted", kind: .success)
        } else {
            toasts.show("Failed to delete account", kind: .error)
        }
        deletingAccount = nil
    }
}
