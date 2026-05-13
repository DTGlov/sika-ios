import Foundation

/// Identifiable handle to a pending reconcile, shared between the
/// Accounts-tab scale-icon entry (presented via `.sheet(item:)`) and
/// the in-wizard reconcile mode (driven via `AppState.reconcileContext`).
///
/// `sikaBalance` is frozen at the time the user tapped — matches web,
/// where the displayed "Sika shows" value doesn't drift if balances
/// recompute mid-flow.
struct ReconcileContext: Identifiable, Equatable {
    let id: UUID
    let accountId: UUID
    let sikaBalance: Decimal

    init(accountId: UUID, sikaBalance: Decimal) {
        self.id = UUID()
        self.accountId = accountId
        self.sikaBalance = sikaBalance
    }
}
