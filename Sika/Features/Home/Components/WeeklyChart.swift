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

    @State private var selectedDate: Date?

    private static let dateKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        return f
    }()

    /// Stable "MMM d" axis + pill format. en_US_POSIX guarantees "May 1"
    /// rendering regardless of device locale (avoids "1 May" in en_GB etc.).
    private static let axisFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        f.locale = Locale(identifier: "en_US_POSIX")
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
            let key = Self.dateKeyFormatter.string(from: normalizedDay)
            dailyTotals.append((date: normalizedDay, key: key, amount: 0))
        }

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
                    y: .value("Spent", NSDecimalNumber(decimal: day.amount).doubleValue),
                    width: .ratio(0.5)
                )
                .foregroundStyle(SikaTheme.Color.bucketNeeds)
                .cornerRadius(3)
            }
            .chartXSelection(value: $selectedDate)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { value in
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(Self.axisFormatter.string(from: date))
                                .font(SikaTheme.Typography.sans(10))
                                .foregroundStyle(SikaTheme.Color.mutedForeground)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                        .foregroundStyle(SikaTheme.Color.border.opacity(0.5))
                    AxisValueLabel {
                        if let raw = value.as(Double.self) {
                            Text(Self.formatAxisAmount(raw))
                                .font(SikaTheme.Typography.sans(10))
                                .foregroundStyle(SikaTheme.Color.mutedForeground)
                        }
                    }
                }
            }
            .chartOverlay { proxy in
                GeometryReader { geo in
                    if let selectedDate, let plotFrame = proxy.plotFrame {
                        let plotRect = geo[plotFrame]
                        let xOffset = proxy.position(forX: selectedDate) ?? 0
                        pill(for: selectedDate)
                            .fixedSize()
                            .position(
                                x: plotRect.minX + xOffset,
                                y: plotRect.minY - 4
                            )
                            .allowsHitTesting(false)
                            .animation(.easeOut(duration: 0.15), value: selectedDate)
                    }
                }
            }
            .frame(height: 140)
        }
        .padding(SikaTheme.Spacing.md)
        .background(SikaTheme.Color.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, SikaTheme.Spacing.lg)
    }

    private var header: some View {
        HStack {
            Text("7-DAY SPEND")
                .font(SikaTheme.Typography.sans(11, weight: .semibold))
                .foregroundStyle(SikaTheme.Color.mutedForeground)
                .tracking(1)
            Spacer()
        }
    }

    private func pill(for date: Date) -> some View {
        let amount = data.first(where: {
            Calendar.current.isDate($0.date, inSameDayAs: date)
        })?.amount ?? 0

        return VStack(spacing: 2) {
            Text(Self.axisFormatter.string(from: date))
                .font(SikaTheme.Typography.sans(11, weight: .semibold))
                .foregroundStyle(SikaTheme.Color.foreground)
            Text(CurrencyFormatter.format(amount, code: currencyCode))
                .font(SikaTheme.Typography.mono(12, weight: .semibold))
                .foregroundStyle(SikaTheme.Color.sikaAccent)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(SikaTheme.Color.card)
                .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)
        )
    }

    /// Y-axis amount formatter. iOS 18+ uses native compact notation
    /// ("1.05K"); iOS 17 falls back to a simple K-suffix.
    private static func formatAxisAmount(_ value: Double) -> String {
        if value == 0 { return "0" }
        if #available(iOS 18, *) {
            let dec = Decimal(value)
            return dec.formatted(.number.notation(.compactName).precision(.fractionLength(0...1)))
        }
        if value >= 1000 {
            return String(format: "%.1fK", value / 1000)
        }
        return String(format: "%.0f", value)
    }
}

private struct DailySpend: Identifiable {
    let id = UUID()
    let date: Date
    let amount: Decimal
}
