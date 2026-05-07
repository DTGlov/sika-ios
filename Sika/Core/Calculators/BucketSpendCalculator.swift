import Foundation
import SwiftUI

/// Computes spent + limit per bucket (Needs/Wants/Savings) for the BucketStrip.
///
/// Bucket grouping comes from each category's bucket_id (resolved through
/// budget_buckets to a canonical name). Display info (color, sort order) is
/// hardcoded — matches web's BUCKET_CONFIG. No iOS Bucket domain model.
///
/// Spent: in-cycle expense transactions whose category belongs to the bucket,
/// excluding paid-from-target transactions (goalId set).
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

        let startStr = dateFormatter.string(from: cycle.start)
        let endStr = dateFormatter.string(from: cycle.end)

        let cycleExpenses = transactions
            .filter { $0.type == .expense }
            .filter { $0.transactionDate >= startStr && $0.transactionDate <= endStr }
            .filter { $0.goalId == nil }

        var spent: [String: Decimal] = ["needs": 0, "wants": 0, "savings": 0]
        for tx in cycleExpenses {
            guard let categoryId = tx.categoryId,
                  let bucketName = categoryIdToBucketName[categoryId] else { continue }
            spent[bucketName, default: 0] += tx.amount
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
