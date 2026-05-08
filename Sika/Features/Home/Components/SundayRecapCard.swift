import SwiftUI
import Supabase

/// Per-week recap that surfaces every Sunday with logging/savings stats.
///
/// Bespoke component — does NOT share chrome with HintCard. Border is
/// 20% opacity (vs HintCard's 30%) and the layout has its own structure.
///
/// Trigger: `Calendar.current.component(.weekday, from: Date()) == 1`
/// (Apple's calendar uses 1=Sunday). Re-evaluated on view appear.
///
/// Hint id rotation: id is per ISO-week, so dismiss only suppresses the
/// current week's recap. Next Sunday automatically generates a new id
/// (no row in dismissed_hints) and the card re-appears.
struct SundayRecapCard: View {
    @Environment(AppState.self) private var appState

    @State private var data: RecapData?
    @State private var loading = true
    @State private var loadFailed = false

    private struct RecapData {
        let loggingDays: Int
        let savedTotal: Decimal
        let goalsCount: Int
    }

    private var hintId: HintId {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .current
        let now = Date()
        let year = calendar.component(.yearForWeekOfYear, from: now)
        let week = calendar.component(.weekOfYear, from: now)
        return .sundayRecap(year: year, week: week)
    }

    private var isSunday: Bool {
        Calendar.current.component(.weekday, from: Date()) == 1
    }

    var body: some View {
        if !isSunday || !appState.hintsLoaded {
            EmptyView()
        } else if appState.isDismissed(hintId) {
            EmptyView()
        } else if loading {
            // While we fetch the recap data, render nothing (matches web).
            Color.clear
                .frame(height: 0)
                .task { await loadData() }
        } else if let data {
            cardContent(data: data)
                .transition(.opacity.combined(with: .move(edge: .top)))
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private func cardContent(data: RecapData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("📊 Your week in money")
                    .font(SikaTheme.Typography.sans(14, weight: .semibold))
                    .foregroundStyle(SikaTheme.Color.foreground)
                Spacer()
                Button(action: dismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(SikaTheme.Color.mutedForeground.opacity(0.7))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss weekly recap")
            }

            VStack(alignment: .leading, spacing: 6) {
                loggingRow(data: data)
                if data.savedTotal > 0 {
                    savedRow(data: data)
                }
                if data.loggingDays == 0 && data.savedTotal == 0 {
                    Text("Quiet week — that's okay. Fresh start tomorrow.")
                        .font(SikaTheme.Typography.sans(12))
                        .foregroundStyle(SikaTheme.Color.mutedForeground)
                }
            }
        }
        .padding(SikaTheme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(SikaTheme.Color.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            SikaTheme.Color.sikaAccent.opacity(0.2),
                            lineWidth: 1
                        )
                )
        )
    }

    private func loggingRow(data: RecapData) -> some View {
        HStack(spacing: 8) {
            Text("🔥")
            Text("Logging:")
                .font(SikaTheme.Typography.sans(14))
                .foregroundStyle(SikaTheme.Color.mutedForeground)
            Text("\(data.loggingDays)/7 days")
                .font(SikaTheme.Typography.sans(14, weight: .semibold))
                .foregroundStyle(SikaTheme.Color.foreground)
        }
    }

    private func savedRow(data: RecapData) -> some View {
        HStack(spacing: 8) {
            Text("💰")
            Text("Saved:")
                .font(SikaTheme.Typography.sans(14))
                .foregroundStyle(SikaTheme.Color.mutedForeground)
            Group {
                Text(CurrencyFormatter.compact(data.savedTotal, code: appState.currencyCode))
                    .font(SikaTheme.Typography.sans(14, weight: .semibold))
                    .foregroundStyle(SikaTheme.Color.foreground)
                +
                (data.goalsCount > 0
                    ? Text(" to \(data.goalsCount) goal\(data.goalsCount == 1 ? "" : "s")")
                        .font(SikaTheme.Typography.sans(14))
                        .foregroundStyle(SikaTheme.Color.mutedForeground)
                    : Text(""))
            }
        }
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.2)) {
            Task { await appState.dismissHint(hintId) }
        }
    }

    /// Fetches the two parallel queries that feed the recap.
    /// Mirrors web's Promise.all in the useEffect.
    private func loadData() async {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .current
        let now = Date()

        // ISO week interval: [Mon 00:00, next Mon 00:00). Sunday is the day before .end.
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now) else {
            await MainActor.run {
                self.loadFailed = true
                self.loading = false
            }
            return
        }
        let weekStart = weekInterval.start
        let weekEnd = calendar.date(byAdding: .day, value: -1, to: weekInterval.end) ?? weekInterval.end

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        let weekStartStr = formatter.string(from: weekStart)
        let weekEndStr = formatter.string(from: weekEnd)

        do {
            // Two parallel queries — matches web's Promise.all.
            async let datesResult = fetchLoggingDates(from: weekStartStr, to: weekEndStr)
            async let contribsResult = fetchSavingsContribs(from: weekStartStr, to: weekEndStr)
            let dates = try await datesResult
            let contribs = try await contribsResult

            let loggingDays = Set(dates).count
            let savedTotal = contribs.reduce(Decimal(0)) { $0 + $1.amount }
            let goalsCount = Set(contribs.compactMap { $0.goalId }).count

            await MainActor.run {
                self.data = RecapData(
                    loggingDays: loggingDays,
                    savedTotal: savedTotal,
                    goalsCount: goalsCount
                )
                self.loading = false
            }
        } catch {
            #if DEBUG
            print("⚠️ SundayRecap data fetch failed: \(error)")
            #endif
            await MainActor.run {
                self.loadFailed = true
                self.loading = false
            }
        }
    }

    /// Fetches transaction_date strings for non-adjustment txns in the week.
    /// RLS scopes to current user automatically — no explicit user_id filter.
    private func fetchLoggingDates(from: String, to: String) async throws -> [String] {
        struct Row: Codable {
            let transaction_date: String
        }
        let response: PostgrestResponse<[Row]> = try await SupabaseManager.shared.client
            .from("transactions")
            .select("transaction_date")
            .neq("type", value: "adjustment")
            .gte("transaction_date", value: from)
            .lte("transaction_date", value: to)
            .execute()
        return response.value.map { $0.transaction_date }
    }

    /// Fetches goal-contribution transfers in the week.
    /// Filter for `goal_id IS NOT NULL` is applied client-side — week's volume
    /// is small (typically <50 rows) and avoids portability issues with the
    /// Supabase Swift SDK's null-filter syntax.
    private func fetchSavingsContribs(from: String, to: String) async throws -> [(amount: Decimal, goalId: UUID)] {
        struct Row: Codable {
            let amount: Decimal
            let goal_id: UUID?
        }
        let response: PostgrestResponse<[Row]> = try await SupabaseManager.shared.client
            .from("transactions")
            .select("amount, goal_id")
            .eq("type", value: "transfer")
            .gte("transaction_date", value: from)
            .lte("transaction_date", value: to)
            .execute()
        return response.value.compactMap { row in
            guard let goalId = row.goal_id else { return nil }
            return (row.amount, goalId)
        }
    }
}
