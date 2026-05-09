import Foundation
import Supabase

/// Computes the user's Sika score (0-100) as a pure function of DB state.
/// Direct port of web's src/lib/health-score.ts — keep in sync.
///
/// Compute order: parallel base fetch → derive cycle ranges → fetch cycle
/// expenses → 5 factor computations → weighted total.
///
/// Caller passes categories + budgetBuckets so the bucket-resolution path
/// reuses the AppState arrays already loaded for Home rendering. Avoids the
/// nested PostgREST embed (`category:categories!category_id(bucket:budget_buckets(name))`).
final class HealthScoreCalculator {
    private var client: SupabaseClient { SupabaseManager.shared.client }

    /// Top-level orchestrator. Mirrors computeHealthScore.
    func computeHealthScore(
        userId: UUID,
        categories: [TransactionCategory],
        budgetBuckets: [BudgetBucket]
    ) async throws -> HealthScore {
        // ── Phase 1: parallel base fetch
        async let profileResult = fetchProfileFields(userId: userId)
        async let streaksResult = fetchStreaksMinimal(userId: userId)
        async let activeGoalsResult = fetchActiveTargetGoals(userId: userId)
        async let accountCountResult = fetchActiveAccountCount(userId: userId)
        async let incomeSourcesResult = fetchActiveIncomeSources(userId: userId)

        let profile      = try await profileResult
        let streaksData  = try await streaksResult
        let activeGoals  = try await activeGoalsResult
        let accountCount = try await accountCountResult
        let incomeSrcs   = try await incomeSourcesResult

        let cycleStartDay = profile?.cycleStartDay ?? 1
        let needsPct = doubleFromDecimal(profile?.needsPercent ?? 50)
        let wantsPct = doubleFromDecimal(profile?.wantsPercent ?? 30)
        let futurePct = doubleFromDecimal(profile?.savingsPercent ?? 20)

        let monthlyIncome: Decimal = incomeSrcs.isEmpty
            ? (profile?.monthlyIncome ?? 0)
            : totalMonthlyIncome(incomeSrcs)

        // ── Phase 2: last 3 completed cycles + cycle expense fetch
        let today = Date()
        let completedCycles: [Cycle] = [-1, -2, -3].map { offset in
            CycleCalculator.cycle(
                atOffset: offset,
                fromDate: today,
                cycleStartDay: cycleStartDay
            )
        }
        let oldestStart = isoString(completedCycles[2].start)
        let newestEnd = isoString(completedCycles[0].end)

        let cycleExpenses = (try? await fetchCycleExpenses(
            userId: userId,
            startDate: oldestStart,
            endDate: newestEnd
        )) ?? []

        // Resolve category id → bucket name from supplied arrays.
        let bucketNameByCategoryId = resolveBucketLookup(
            categories: categories,
            budgetBuckets: budgetBuckets
        )

        // ── Phase 3: 5 factors
        let f1 = await computeEmergencyCoverage(
            userId: userId,
            cycleExpenses: cycleExpenses,
            completedCycles: completedCycles,
            bucketNameByCategoryId: bucketNameByCategoryId
        )
        let f2 = computeBudgetDiscipline(
            cycleExpenses: cycleExpenses,
            completedCycles: completedCycles,
            monthlyIncome: monthlyIncome,
            needsPct: needsPct,
            wantsPct: wantsPct,
            futurePct: futurePct,
            bucketNameByCategoryId: bucketNameByCategoryId
        )
        let f3 = computeConsistency(streaksData: streaksData)
        let f4 = await computeGoalCommitment(activeGoals: activeGoals)
        let f5 = computeDiversification(
            accountCount: accountCount,
            incomeSourceCount: incomeSrcs.count
        )

        // ── Weighted total
        let total = Int(round(
            Double(f1.score) * 0.25 +
            Double(f2.score) * 0.25 +
            Double(f3.score) * 0.20 +
            Double(f4.score) * 0.20 +
            Double(f5.score) * 0.10
        ))

        return HealthScore(
            total: total,
            label: HealthLabel.from(score: total),
            factors: [f1, f2, f3, f4, f5]
        )
    }

    // MARK: - Factor 1: Emergency Coverage (25%)

    private func computeEmergencyCoverage(
        userId: UUID,
        cycleExpenses: [CycleExpenseRow],
        completedCycles: [Cycle],
        bucketNameByCategoryId: [UUID: String]
    ) async -> HealthFactor {
        let id = HealthFactorId.emergencyCoverage

        // Find Life Savings perpetual goal
        struct GoalRow: Codable {
            let id: UUID
        }
        let lsGoal: GoalRow?
        do {
            let response: PostgrestResponse<[GoalRow]> = try await client
                .from("goals")
                .select("id")
                .eq("user_id", value: userId)
                .eq("goal_type", value: "perpetual")
                .ilike("name", value: "life savings")
                .limit(1)
                .execute()
            lsGoal = response.value.first
        } catch {
            lsGoal = nil
        }

        guard let goal = lsGoal else {
            return makeNeutralFactor(
                id: id,
                description: "No Life Savings goal found — create one to track your emergency fund."
            )
        }

        let lsBalance = (try? await fetchGoalNet(goalId: goal.id)) ?? 0

        let needsPerCycle: [Decimal] = completedCycles.compactMap { cycle in
            let startStr = isoString(cycle.start)
            let endStr = isoString(cycle.end)
            let sum = cycleExpenses
                .filter { $0.transactionDate >= startStr && $0.transactionDate <= endStr }
                .filter { row in
                    guard let cid = row.categoryId else { return false }
                    return bucketNameByCategoryId[cid] == "needs"
                }
                .reduce(Decimal(0)) { $0 + $1.amount }
            return sum > 0 ? sum : nil
        }

        guard !needsPerCycle.isEmpty else {
            return makeNeutralFactor(id: id, description: "No Needs spending data yet.")
        }

        let monthlyNeedsAvg = needsPerCycle.reduce(Decimal(0), +) / Decimal(needsPerCycle.count)
        let lsBalanceD = doubleFromDecimal(lsBalance)
        let monthlyNeedsD = doubleFromDecimal(monthlyNeedsAvg)
        guard monthlyNeedsD > 0 else {
            return makeNeutralFactor(id: id, description: "No Needs spending data yet.")
        }

        let coverageRatio = lsBalanceD / monthlyNeedsD
        let score = min(100, Int((coverageRatio / 3.0 * 100.0).rounded()))
        let monthsCovered = String(format: "%.1f", coverageRatio)
        let monthsValue = Double(monthsCovered) ?? 0

        let description: String = lsBalanceD <= 0
            ? "Life Savings has no balance yet."
            : "Your Life Savings covers \(monthsCovered) month\(monthsValue == 1 ? "" : "s") of Needs."

        let targetAmount = monthlyNeedsD * 3
        let tip: String? = score < 60
            ? "Build Life Savings to cover 3 months of your Needs (~\(formatPts(targetAmount)))"
            : nil

        return HealthFactor(
            id: id, name: id.displayName, weight: id.weight,
            score: score, description: description, tip: tip
        )
    }

    // MARK: - Factor 2: Budget Discipline (25%)

    private func computeBudgetDiscipline(
        cycleExpenses: [CycleExpenseRow],
        completedCycles: [Cycle],
        monthlyIncome: Decimal,
        needsPct: Double,
        wantsPct: Double,
        futurePct: Double,
        bucketNameByCategoryId: [UUID: String]
    ) -> HealthFactor {
        let id = HealthFactorId.budgetDiscipline

        let income = doubleFromDecimal(monthlyIncome)
        if cycleExpenses.isEmpty || income <= 0 {
            return makeNeutralFactor(id: id, description: "No completed cycles to evaluate yet.")
        }

        let limits: [String: Double] = [
            "needs":   income * needsPct / 100.0,
            "wants":   income * wantsPct / 100.0,
            "savings": income * futurePct / 100.0,
        ]

        var totalChecks = 0
        var withinCount = 0
        var overCounts: [String: Int] = ["needs": 0, "wants": 0, "savings": 0]

        for cycle in completedCycles {
            let startStr = isoString(cycle.start)
            let endStr = isoString(cycle.end)

            for bucket in ["needs", "wants", "savings"] {
                let bucketSpend = cycleExpenses
                    .filter { $0.transactionDate >= startStr && $0.transactionDate <= endStr }
                    .filter { row in
                        guard let cid = row.categoryId else { return false }
                        return bucketNameByCategoryId[cid] == bucket
                    }
                    .reduce(Decimal(0)) { $0 + $1.amount }

                totalChecks += 1
                let spendD = doubleFromDecimal(bucketSpend)
                let limit = limits[bucket] ?? 0
                if spendD <= limit {
                    withinCount += 1
                } else {
                    overCounts[bucket, default: 0] += 1
                }
            }
        }

        guard totalChecks > 0 else {
            return makeNeutralFactor(id: id, description: "No completed cycles to evaluate yet.")
        }

        let score = Int((Double(withinCount) / Double(totalChecks) * 100.0).rounded())
        let description = "Stayed within limit in \(withinCount) of \(totalChecks) bucket-cycles."

        let mostBlow = overCounts.max(by: { $0.value < $1.value })
        let tip: String? = (score < 60 && (mostBlow?.value ?? 0) > 0)
            ? "Your \(mostBlow!.key.capitalized) bucket has been over limit. Aim to keep it within this month's split."
            : nil

        return HealthFactor(
            id: id, name: id.displayName, weight: id.weight,
            score: score, description: description, tip: tip
        )
    }

    // MARK: - Factor 3: Consistency (20%)

    private func computeConsistency(streaksData: StreaksMinimal?) -> HealthFactor {
        let id = HealthFactorId.consistency

        guard let s = streaksData else {
            return makeNeutralFactor(id: id, description: "No streak data yet. Start logging daily.")
        }

        let loggingScore = min(100, Int((Double(s.loggingCurrent) / 30.0 * 100.0).rounded()))
        let savingsScore = min(100, Int((Double(s.savingsCurrent) / 4.0 * 100.0).rounded()))
        let score = Int((Double(loggingScore) * 0.6 + Double(savingsScore) * 0.4).rounded())

        let description = "\(s.loggingCurrent)-day logging streak · \(s.savingsCurrent)-week savings streak."

        let tip: String? = score < 60
            ? (loggingScore <= savingsScore
                ? "Log a transaction today to keep your streak going."
                : "Contribute to a goal this week to build your saving streak.")
            : nil

        return HealthFactor(
            id: id, name: id.displayName, weight: id.weight,
            score: score, description: description, tip: tip
        )
    }

    // MARK: - Factor 4: Goal Commitment (20%)

    private func computeGoalCommitment(activeGoals: [GoalRow]) async -> HealthFactor {
        let id = HealthFactorId.goalCommitment

        if activeGoals.isEmpty {
            return makeNeutralFactor(
                id: id,
                description: "No active target goals. Add one to track your commitment."
            )
        }

        // Fetch nets in parallel via TaskGroup
        var amounts: [(goal: GoalRow, net: Decimal)] = []
        await withTaskGroup(of: (GoalRow, Decimal).self) { group in
            for g in activeGoals {
                group.addTask {
                    let net = (try? await self.fetchGoalNet(goalId: g.id)) ?? 0
                    return (g, net)
                }
            }
            for await pair in group {
                amounts.append(pair)
            }
        }

        var onPace = 0
        var totalEvaluated = 0
        var worstGoal: (name: String, pace: Double)? = nil
        var worstPaceDeficit: Double = 0

        let today = Date()
        let cal = Calendar.current

        let deadlineFormatter = DateFormatter()
        deadlineFormatter.dateFormat = "yyyy-MM-dd"
        deadlineFormatter.locale = Locale(identifier: "en_US_POSIX")
        deadlineFormatter.timeZone = .current

        for (goal, net) in amounts {
            guard let target = goal.targetAmount, target > 0,
                  let deadlineStr = goal.deadline,
                  let deadline = deadlineFormatter.date(from: deadlineStr)
            else { continue }
            let createdAt = goal.createdAt

            let daysRemaining = max(0, daysBetween(from: today, to: deadline, calendar: cal))
            let totalDays = daysBetween(from: createdAt, to: deadline, calendar: cal)
            guard totalDays > 0 else { continue }
            totalEvaluated += 1

            let elapsed = Double(totalDays - daysRemaining)
            let totalDaysD = Double(totalDays)
            let targetD = doubleFromDecimal(target)
            let netD = doubleFromDecimal(net)
            let expectedByNow = (elapsed / totalDaysD) * targetD

            if netD >= expectedByNow {
                onPace += 1
            } else {
                let deficit = expectedByNow - netD
                let monthlyNeeded = daysRemaining > 0
                    ? (targetD - netD) / (Double(daysRemaining) / 30.0)
                    : 0
                if deficit > worstPaceDeficit {
                    worstPaceDeficit = deficit
                    worstGoal = (goal.name, monthlyNeeded)
                }
            }
        }

        let score = totalEvaluated > 0
            ? Int((Double(onPace) / Double(totalEvaluated) * 100.0).rounded())
            : 50
        let description: String = totalEvaluated > 0
            ? "\(onPace) of \(totalEvaluated) active goal\(totalEvaluated == 1 ? "" : "s") on pace."
            : "No deadline-based goals to evaluate."

        let tip: String? = (score < 60 && worstGoal != nil)
            ? "Your \(worstGoal!.name) goal needs \(formatPts(worstGoal!.pace))/month to stay on track."
            : nil

        return HealthFactor(
            id: id, name: id.displayName, weight: id.weight,
            score: score, description: description, tip: tip
        )
    }

    // MARK: - Factor 5: Diversification (10%)

    private func computeDiversification(accountCount: Int, incomeSourceCount: Int) -> HealthFactor {
        let id = HealthFactorId.diversification
        let accountScore = min(100.0, Double(accountCount) / 3.0 * 100.0)
        let incomeScore = min(100.0, Double(incomeSourceCount) / 2.0 * 100.0)
        let score = Int((accountScore * 0.5 + incomeScore * 0.5).rounded())

        let description = "\(accountCount) account\(accountCount == 1 ? "" : "s") · \(incomeSourceCount) income source\(incomeSourceCount == 1 ? "" : "s")."

        let tip: String? = score < 50
            ? (incomeScore < accountScore
                ? "Add a second income source to diversify."
                : "Add your MoMo or Savings account to diversify.")
            : nil

        return HealthFactor(
            id: id, name: id.displayName, weight: id.weight,
            score: score, description: description, tip: tip
        )
    }

    // MARK: - Supabase fetches

    struct ProfileFields: Codable {
        let cycleStartDay: Int?
        let monthlyIncome: Decimal?
        let needsPercent: Decimal?
        let wantsPercent: Decimal?
        let savingsPercent: Decimal?

        enum CodingKeys: String, CodingKey {
            case cycleStartDay  = "cycle_start_day"
            case monthlyIncome  = "monthly_income"
            case needsPercent   = "needs_percent"
            case wantsPercent   = "wants_percent"
            case savingsPercent = "savings_percent"
        }
    }

    private func fetchProfileFields(userId: UUID) async throws -> ProfileFields? {
        let response: PostgrestResponse<[ProfileFields]> = try await client
            .from("profiles")
            .select("cycle_start_day, monthly_income, needs_percent, wants_percent, savings_percent")
            .eq("id", value: userId)
            .limit(1)
            .execute()
        return response.value.first
    }

    /// Lightweight projection of streaks needed by the consistency factor.
    struct StreaksMinimal: Codable {
        let loggingCurrent: Int
        let savingsCurrent: Int
        let loggingLastDate: String?

        enum CodingKeys: String, CodingKey {
            case loggingCurrent = "logging_current"
            case savingsCurrent = "savings_current"
            case loggingLastDate = "logging_last_date"
        }
    }

    private func fetchStreaksMinimal(userId: UUID) async throws -> StreaksMinimal? {
        let response: PostgrestResponse<[StreaksMinimal]> = try await client
            .from("streaks")
            .select("logging_current, savings_current, logging_last_date")
            .eq("user_id", value: userId)
            .limit(1)
            .execute()
        return response.value.first
    }

    /// Internal goal projection for the goal_commitment factor.
    /// Mirrors web's filter: is_active=true, is_archived=false, goal_type=target,
    /// completed_at IS NULL, deadline IS NOT NULL. The IS-NULL filters are
    /// applied in Swift after fetch — the iOS Supabase SDK's `.is()` filter
    /// signature is awkward, and existing services in this repo also fetch
    /// loosely + filter post-hoc (see MonthlyRecapService for precedent).
    struct GoalRow: Codable {
        let id: UUID
        let name: String
        let targetAmount: Decimal?
        /// YYYY-MM-DD string (Supabase `date` column). Parsed on demand.
        let deadline: String?
        let createdAt: Date
        let completedAt: Date?

        enum CodingKeys: String, CodingKey {
            case id
            case name
            case targetAmount = "target_amount"
            case deadline
            case createdAt = "created_at"
            case completedAt = "completed_at"
        }
    }

    private func fetchActiveTargetGoals(userId: UUID) async throws -> [GoalRow] {
        let response: PostgrestResponse<[GoalRow]> = try await client
            .from("goals")
            .select("id, name, target_amount, deadline, created_at, completed_at")
            .eq("user_id", value: userId)
            .eq("is_active", value: true)
            .eq("is_archived", value: false)
            .eq("goal_type", value: "target")
            .execute()
        return response.value.filter { $0.completedAt == nil && $0.deadline != nil }
    }

    private func fetchActiveAccountCount(userId: UUID) async throws -> Int {
        let response = try await client
            .from("accounts")
            .select("id", head: true, count: .exact)
            .eq("user_id", value: userId)
            .eq("is_active", value: true)
            .execute()
        return response.count ?? 0
    }

    private func fetchActiveIncomeSources(userId: UUID) async throws -> [IncomeSource] {
        let response: PostgrestResponse<[IncomeSource]> = try await client
            .from("income_sources")
            .select()
            .eq("user_id", value: userId)
            .eq("is_active", value: true)
            .execute()
        return response.value
    }

    /// Cycle expense rows: amount + date + categoryId. Bucket resolution
    /// happens caller-side via the supplied categories array.
    struct CycleExpenseRow: Codable {
        let amount: Decimal
        let transactionDate: String
        let categoryId: UUID?

        enum CodingKeys: String, CodingKey {
            case amount
            case transactionDate = "transaction_date"
            case categoryId = "category_id"
        }
    }

    private func fetchCycleExpenses(
        userId: UUID,
        startDate: String,
        endDate: String
    ) async throws -> [CycleExpenseRow] {
        let response: PostgrestResponse<[CycleExpenseRow]> = try await client
            .from("transactions")
            .select("amount, transaction_date, category_id")
            .eq("user_id", value: userId)
            .eq("type", value: "expense")
            .gte("transaction_date", value: startDate)
            .lte("transaction_date", value: endDate)
            .execute()
        return response.value
    }

    /// Net balance for a goal. Mirror of web's lib/goals.ts net pattern.
    /// Reads the transactions table (NOT a separate goal_contributions table —
    /// iOS encodes the relationship via Transaction.goal_id and
    /// .paid_from_goal_id columns).
    ///
    /// net = sum(amount where goal_id = G) - sum(amount where paid_from_goal_id = G)
    private func fetchGoalNet(goalId: UUID) async throws -> Decimal {
        struct Row: Codable {
            let amount: Decimal
        }

        let inflowsResponse: PostgrestResponse<[Row]> = try await client
            .from("transactions")
            .select("amount")
            .eq("goal_id", value: goalId)
            .execute()

        let outflowsResponse: PostgrestResponse<[Row]> = try await client
            .from("transactions")
            .select("amount")
            .eq("paid_from_goal_id", value: goalId)
            .execute()

        let inflowSum = inflowsResponse.value.reduce(Decimal(0)) { $0 + $1.amount }
        let outflowSum = outflowsResponse.value.reduce(Decimal(0)) { $0 + $1.amount }
        return inflowSum - outflowSum
    }

    // MARK: - Helpers

    private func makeNeutralFactor(id: HealthFactorId, description: String) -> HealthFactor {
        HealthFactor(
            id: id, name: id.displayName, weight: id.weight,
            score: 50, description: description, tip: nil
        )
    }

    private func resolveBucketLookup(
        categories: [TransactionCategory],
        budgetBuckets: [BudgetBucket]
    ) -> [UUID: String] {
        let bucketNameById: [UUID: String] = Dictionary(
            uniqueKeysWithValues: budgetBuckets.map { ($0.id, $0.name.lowercased()) }
        )
        var lookup: [UUID: String] = [:]
        for cat in categories {
            if let bid = cat.bucketId, let name = bucketNameById[bid] {
                lookup[cat.id] = name
            }
        }
        return lookup
    }

    private func isoString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        return f.string(from: date)
    }

    private func doubleFromDecimal(_ d: Decimal) -> Double {
        Double(truncating: d as NSNumber)
    }

    private func daysBetween(from: Date, to: Date, calendar: Calendar) -> Int {
        let fromDay = calendar.startOfDay(for: from)
        let toDay = calendar.startOfDay(for: to)
        let comps = calendar.dateComponents([.day], from: fromDay, to: toDay)
        return comps.day ?? 0
    }

    private func formatPts(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.maximumFractionDigits = 0
        let rounded = amount.rounded()
        let str = formatter.string(from: NSNumber(value: rounded)) ?? "\(Int(rounded))"
        return "₵\(str)"
    }
}
