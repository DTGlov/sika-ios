import Foundation

/// Computes spend totals over various time windows for Home dashboard cards.
///
/// `Transaction.transactionDate` is stored as a `yyyy-MM-dd` String. We compare
/// using string equality / lexicographic ordering since ISO date strings sort
/// equivalently to dates and avoid per-row parsing cost.
enum SpendCalculator {
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        return f
    }()

    private static func dateString(_ date: Date) -> String {
        dateFormatter.string(from: date)
    }

    /// Total expense for a specific calendar day.
    static func todaysSpent(transactions: [Transaction], reference: Date = Date()) -> Decimal {
        let today = dateString(reference)
        let expenses = transactions.filter { $0.type == .expense }
        let filtered = expenses.filter { $0.transactionDate == today }

        #if DEBUG
        print("[SpendCalculator.todaysSpent] reference=\(reference) todayString=\(today)")
        print("  input count: \(transactions.count)")
        print("  after .expense filter: \(expenses.count)")
        print("  after isSameDay filter: \(filtered.count)")
        if !filtered.isEmpty {
            print("  matched: \(filtered.map { $0.amount })")
        }
        #endif

        return filtered.reduce(Decimal(0)) { $0 + $1.amount }
    }

    /// Total expense for the current calendar month (NOT the cycle window).
    static func currentMonthSpent(transactions: [Transaction], reference: Date = Date()) -> Decimal {
        #if DEBUG
        print("[SpendCalculator.currentMonthSpent] reference=\(reference)")
        #endif
        return sumExpenses(transactions, calendarMonthsAgo: 0, from: reference)
    }

    /// Total expense for the previous calendar month.
    static func previousMonthSpent(transactions: [Transaction], reference: Date = Date()) -> Decimal {
        #if DEBUG
        print("[SpendCalculator.previousMonthSpent] reference=\(reference)")
        #endif
        return sumExpenses(transactions, calendarMonthsAgo: 1, from: reference)
    }

    /// Cycle-bounded received total (income transactions in cycle).
    static func cycleReceived(transactions: [Transaction], cycle: Cycle) -> Decimal {
        let start = dateString(cycle.start)
        let end = dateString(cycle.end)
        let incomes = transactions.filter { $0.type == .income }
        let filtered = incomes.filter { $0.transactionDate >= start && $0.transactionDate <= end }

        #if DEBUG
        print("[SpendCalculator.cycleReceived] cycle.start=\(cycle.start) cycle.end=\(cycle.end)")
        print("  window strings: \(start) ... \(end)")
        print("  input count: \(transactions.count)")
        print("  after .income filter: \(incomes.count)")
        print("  after window filter: \(filtered.count)")
        if !filtered.isEmpty {
            print("  matched: \(filtered.map { $0.amount })")
        }
        #endif

        return filtered.reduce(Decimal(0)) { $0 + $1.amount }
    }

    /// Cycle-bounded spent total (expense transactions in cycle).
    /// In Phase 1 we don't have the Goal domain on iOS, so the goal_id exclusion
    /// is deferred. Phase 2 will add: `.filter { $0.goalId == nil }`.
    static func cycleSpent(transactions: [Transaction], cycle: Cycle) -> Decimal {
        let start = dateString(cycle.start)
        let end = dateString(cycle.end)
        let expenses = transactions.filter { $0.type == .expense }
        let filtered = expenses.filter { $0.transactionDate >= start && $0.transactionDate <= end }
            // .filter { $0.goalId == nil }  // Phase 2 when Goal model ships

        #if DEBUG
        print("[SpendCalculator.cycleSpent] cycle.start=\(cycle.start) cycle.end=\(cycle.end)")
        print("  window strings: \(start) ... \(end)")
        print("  input count: \(transactions.count)")
        print("  after .expense filter: \(expenses.count)")
        print("  after window filter: \(filtered.count)")
        if !filtered.isEmpty {
            print("  matched: \(filtered.map { $0.amount })")
        }
        #endif

        return filtered.reduce(Decimal(0)) { $0 + $1.amount }
    }

    /// Cycle-bounded net (received - spent). Can be negative.
    static func cycleNet(transactions: [Transaction], cycle: Cycle) -> Decimal {
        cycleReceived(transactions: transactions, cycle: cycle)
            - cycleSpent(transactions: transactions, cycle: cycle)
    }

    /// Delta percent from previous month to current month.
    /// Returns nil when previous month is 0 (no comparison possible).
    static func monthOverMonthDeltaPercent(current: Decimal, previous: Decimal) -> Decimal? {
        guard previous > 0 else { return nil }
        return ((current - previous) / previous) * 100
    }

    // MARK: - Private

    private static func sumExpenses(_ transactions: [Transaction], calendarMonthsAgo monthsAgo: Int, from reference: Date) -> Decimal {
        let calendar = Calendar.current
        let monthStart = calendar.startOfMonth(for: reference)
        guard let targetMonthStart = calendar.date(byAdding: .month, value: -monthsAgo, to: monthStart),
              let nextMonthStart = calendar.date(byAdding: .month, value: 1, to: targetMonthStart),
              let targetMonthEnd = calendar.date(byAdding: .day, value: -1, to: nextMonthStart) else {
            #if DEBUG
            print("  [sumExpenses] window calc failed for monthsAgo=\(monthsAgo)")
            #endif
            return 0
        }
        let startStr = dateString(targetMonthStart)
        let endStr = dateString(targetMonthEnd)

        let expenses = transactions.filter { $0.type == .expense }
        let filtered = expenses.filter { $0.transactionDate >= startStr && $0.transactionDate <= endStr }

        #if DEBUG
        print("  [sumExpenses] monthsAgo=\(monthsAgo) window: \(startStr) ... \(endStr)")
        print("    input count: \(transactions.count)")
        print("    after .expense filter: \(expenses.count)")
        print("    after month filter: \(filtered.count)")
        if !filtered.isEmpty {
            print("    matched: \(filtered.map { $0.amount })")
        }
        #endif

        return filtered.reduce(Decimal(0)) { $0 + $1.amount }
    }
}

private extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? date
    }
}
