import Foundation

/// Pure balance derivation. Mirror of computeAccountBalances (lib/accounts.ts).
///
/// Sign conventions:
/// - income:     balances[account_id]   += amount
/// - expense:    balances[account_id]   -= amount
/// - transfer:   balances[account_id]   -= amount  (FROM)
///               balances[to_account_id] += amount  (TO)
/// - adjustment: balances[account_id]   += amount  (signed; positive or negative)
///
/// Convention matches T1's `account_id`=source / `to_account_id`=destination.
enum AccountBalanceEngine {
    /// Returns a map of account.id → derived balance.
    /// Seeded with each account's `openingBalance` (or 0 if nil).
    static func compute(
        accounts: [Account],
        transactions: [Transaction]
    ) -> [UUID: Decimal] {
        var balances: [UUID: Decimal] = [:]

        // Seed with opening balances (default to 0 when nil).
        for acc in accounts {
            balances[acc.id] = acc.openingBalance ?? 0
        }

        // Apply transactions
        for txn in transactions {
            switch txn.type {
            case .income:
                if balances[txn.accountId] != nil {
                    balances[txn.accountId, default: 0] += txn.amount
                }
            case .expense:
                if balances[txn.accountId] != nil {
                    balances[txn.accountId, default: 0] -= txn.amount
                }
            case .transfer:
                if balances[txn.accountId] != nil {
                    balances[txn.accountId, default: 0] -= txn.amount
                }
                if let toId = txn.toAccountId, balances[toId] != nil {
                    balances[toId, default: 0] += txn.amount
                }
            case .adjustment:
                if balances[txn.accountId] != nil {
                    balances[txn.accountId, default: 0] += txn.amount
                }
            }
        }

        return balances
    }

    /// Lookup helper with fallback to opening balance.
    static func balance(for account: Account, in balances: [UUID: Decimal]) -> Decimal {
        balances[account.id] ?? account.openingBalance ?? 0
    }
}
