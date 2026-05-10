import Foundation
import SwiftUI

/// Computes spent + limit per bucket (Needs/Wants/Savings) for the BucketStrip.
///
/// Bucket grouping comes from each category's bucket_id (resolved through
/// budget_buckets to a canonical name). Display info (color, sort order) is
/// hardcoded — matches web's BUCKET_CONFIG. No iOS Bucket domain model.
///
/// Spent — Needs/Wants: in-cycle expense transactions whose category belongs
/// to the bucket, excluding expenses paid from a goal's saved funds
/// (paidFromGoalId set).
/// Spent — Savings: same expense pass PLUS a second pass over in-cycle
/// transfers that capture goal contributions (Rule 1) and inbound
/// savings/investment account transfers (Rule 2). Mirrors web's
/// use-dashboard-data.ts:114-156.
/// Limit: monthlyIncome × bucket-percent / 100.
enum BucketSpendCalculator {
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        return f
    }()

    static func compute(
        transactions: [Transaction],
        categories: [TransactionCategory],
        budgetBuckets: [BudgetBucket],
        accounts: [Account],
        cycle: Cycle,
        monthlyIncome: Decimal,
        needsPercent: Decimal,
        wantsPercent: Decimal,
        savingsPercent: Decimal
    ) -> [BucketRow] {
        // bucket UUID → canonical lowercase name
        let bucketIdToName: [UUID: String] = Dictionary(
            uniqueKeysWithValues: budgetBuckets.map { ($0.id, $0.name.lowercased()) }
        )

        // category UUID → bucket name
        let categoryIdToBucketName: [UUID: String] = Dictionary(
            uniqueKeysWithValues: categories.compactMap { cat in
                guard let bucketId = cat.bucketId,
                      let name = bucketIdToName[bucketId] else { return nil }
                return (cat.id, name)
            }
        )

        // account UUID → account type, for Rule 2's savings-like check
        let accountTypeById: [UUID: AccountType] = Dictionary(
            uniqueKeysWithValues: accounts.map { ($0.id, $0.accountType) }
        )

        let startStr = dateFormatter.string(from: cycle.start)
        let endStr = dateFormatter.string(from: cycle.end)

        // Mirrors web's bucketExpenses: expenses excluding those paid from
        // a goal's saved funds (the cost was already counted as a savings
        // bucket contribution at the time of the goal transfer).
        let cycleExpenses = transactions
            .filter { $0.type == .expense }
            .filter { $0.transactionDate >= startStr && $0.transactionDate <= endStr }
            .filter { $0.paidFromGoalId == nil }

        var spent: [String: Decimal] = ["needs": 0, "wants": 0, "savings": 0]
        for tx in cycleExpenses {
            guard let categoryId = tx.categoryId,
                  let bucketName = categoryIdToBucketName[categoryId] else { continue }
            spent[bucketName, default: 0] += tx.amount
        }

        // Savings bucket: also count goal contributions and inbound
        // savings-account transfers within the cycle.
        // Mirrors web's use-dashboard-data.ts:134-156.
        let cycleTransfers = transactions
            .filter { $0.type == .transfer }
            .filter { $0.transactionDate >= startStr && $0.transactionDate <= endStr }

        for tx in cycleTransfers {
            // Rule 1: any transfer with goal_id counts as savings,
            // regardless of account types. Mutually exclusive with Rule 2
            // (the early continue prevents double-counting).
            if tx.goalId != nil {
                spent["savings", default: 0] += tx.amount
                continue
            }

            // Rule 2: transfer TO a savings/investment account that did NOT
            // come from a savings/investment account. Internal savings
            // shuffles (savings → savings, investment → investment) are
            // skipped — no new money entered the savings sphere.
            // Per web's convention: accountId = source (FROM),
            // toAccountId = destination (TO).
            let fromType = accountTypeById[tx.accountId]
            let toType = tx.toAccountId.flatMap { accountTypeById[$0] }

            guard let toType, AccountType.savingsLike.contains(toType) else { continue }

            // toType is savings-like. Source must NOT be savings-like.
            // Web: `(!fromType || !SAVINGS_ACCOUNT_TYPES.has(fromType))`.
            if let fromType, AccountType.savingsLike.contains(fromType) {
                continue  // savings → savings shuffle, skip
            }

            spent["savings", default: 0] += tx.amount
        }

        let limits: [String: Decimal] = [
            "needs": monthlyIncome * needsPercent / 100,
            "wants": monthlyIncome * wantsPercent / 100,
            "savings": monthlyIncome * savingsPercent / 100
        ]

        return [
            BucketRow(name: "Needs", spent: spent["needs"] ?? 0, limit: limits["needs"] ?? 0, color: .needs),
            BucketRow(name: "Wants", spent: spent["wants"] ?? 0, limit: limits["wants"] ?? 0, color: .wants),
            BucketRow(name: "Savings", spent: spent["savings"] ?? 0, limit: limits["savings"] ?? 0, color: .savings)
        ]
    }

    struct BucketRow: Identifiable, Equatable {
        let name: String
        let spent: Decimal
        let limit: Decimal
        let color: BucketColor

        var id: String { name }
    }

    enum BucketColor {
        case needs
        case wants
        case savings

        var swiftUIColor: Color {
            switch self {
            case .needs: return SikaTheme.Color.bucketNeeds
            case .wants: return SikaTheme.Color.bucketWants
            case .savings: return SikaTheme.Color.bucketSavings
            }
        }
    }
}
