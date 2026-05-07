import SwiftUI
import Charts

/// Bar chart showing the last 7 days of expense spend within the cycle.
///
/// Cycle-aware "now" anchoring:
/// - Current cycle: uses `min(today, cycle.end)` as the rightmost day,
///   so users see "today and the 6 days before today".
/// - Past cycle: uses `cycle.end` as the rightmost day, showing the
///   last 7 days of that historical cycle.
///
/// Spend semantics match web's bucketExpenses: type==.expense AND
/// paidFromGoalId is nil. Goal contributions and savings transfers
/// do NOT appear here, even though they DO count in the Savings bucket.
struct WeeklyChart: View {
    let transactions: [Transaction]
    let cycle: Cycle
    let currencyCode: String

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        return f
    }()

    private var data: [DailySpend] {
        let calendar = Calendar.current
        let today = Date()

        // Anchor: clamp to today on current cycle, otherwise cycle.end.
        let anchor: Date = cycle.isCurrent ? min(today, cycle.end) : cycle.end

        // Build the 7-day window, oldest-first. Pre-seed all 7 days with zero
        // so empty days still render with a flat bar.
        var dailyTotals: [(date: Date, key: String, amount: Decimal)] = []
        for i in stride(from: 6, through: 0, by: -1) {
            let day = calendar.date(byAdding: .day, value: -i, to: anchor) ?? anchor
            let normalizedDay = calendar.startOfDay(for: day)
            let key = Self.dateFormatter.string(from: normalizedDay)
            dailyTotals.append((date: normalizedDay, key: key, amount: 0))
        }

        // index by key for O(1) aggregation
        var keyToIndex: [String: Int] = [:]
        for (idx, entry) in dailyTotals.enumerated() {
            keyToIndex[entry.key] = idx
        }

        let cycleExpenses = transactions
            .filter { $0.type == .expense }
            .filter { $0.paidFromGoalId == nil }
            .filter { keyToIndex[$0.transactionDate] != nil }

        for tx in cycleExpenses {
            if let idx = keyToIndex[tx.transactionDate] {
                dailyTotals[idx].amount += tx.amount
            }
        }

        return dailyTotals.map { DailySpend(date: $0.date, amount: $0.amount) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SikaTheme.Spacing.md) {
            header

            Chart(data) { day in
                BarMark(
                    x: .value("Date", day.date, unit: .day),
                    y: .value("Spent", NSDecimalNumber(decimal: day.amount).doubleValue)
                )
                .foregroundStyle(SikaTheme.Color.sikaAccent)
                .cornerRadius(4)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day(),
                                   centered: true)
                        .font(SikaTheme.Typography.sans(10))
                        .foregroundStyle(SikaTheme.Color.mutedForeground)
                }
            }
            .chartYAxis(.hidden)
            .frame(height: 140)
        }
        .padding(SikaTheme.Spacing.md)
        .background(SikaTheme.Color.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, SikaTheme.Spacing.lg)
    }

    private var header: some View {
        HStack {
            Text("WEEKLY · LAST 7 DAYS")
                .font(SikaTheme.Typography.sans(11, weight: .semibold))
                .foregroundStyle(SikaTheme.Color.mutedForeground)
                .tracking(1)
            Spacer()
        }
    }
}

private struct DailySpend: Identifiable {
    let id = UUID()
    let date: Date
    let amount: Decimal
}
