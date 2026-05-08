import SwiftUI

/// Cycle Details page. Pushed from CycleCard tap.
/// Mirrors web's /dashboard/cycle-detail/page.tsx (~242 lines).
///
/// Single Supabase fetch + in-memory aggregation. Skeleton during load,
/// then immediate render. No row taps; read-only.
struct CycleDetailView: View {
    let cycle: Cycle

    @Environment(AppState.self) private var appState

    @State private var summary: CycleDetailSummary?
    @State private var isLoading = true
    @State private var hasErrored = false

    private let service = CycleDetailService()

    private var categoriesById: [UUID: TransactionCategory] {
        Dictionary(uniqueKeysWithValues: appState.categories.map { ($0.id, $0) })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SikaTheme.Spacing.xl) {
                if isLoading {
                    loadingSkeleton
                } else if let summary {
                    NetCashFlowHero(summary: summary, currencyCode: appState.currencyCode)
                    HowCalculatedCard(summary: summary, currencyCode: appState.currencyCode)

                    if !summary.receivedBySource.isEmpty {
                        ReceivedSourcesList(
                            rows: summary.receivedBySource,
                            currencyCode: appState.currencyCode
                        )
                    }

                    if !summary.topSpending.isEmpty {
                        TopCategoriesList(
                            rows: summary.topSpending,
                            totalSpent: summary.totalSpent,
                            currencyCode: appState.currencyCode
                        )
                    }

                    if summary.isEmpty {
                        Text("No transactions logged this cycle yet.")
                            .font(SikaTheme.Typography.sans(14))
                            .foregroundStyle(SikaTheme.Color.mutedForeground)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 48)
                    }
                } else if hasErrored {
                    Text("Could not load cycle details. Try again.")
                        .font(SikaTheme.Typography.sans(14))
                        .foregroundStyle(SikaTheme.Color.mutedForeground)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 48)
                }
            }
            .padding(.horizontal, SikaTheme.Spacing.lg)
            .padding(.top, SikaTheme.Spacing.lg)
            .padding(.bottom, 96)
        }
        .navigationTitle("Cycle Details")
        .navigationBarTitleDisplayMode(.inline)
        .background(SikaTheme.Color.background)
        .task(id: cycleStartString) {
            await loadSummary()
        }
    }

    /// Cycle start as a stable identifier for `.task(id:)`.
    /// Re-runs the load only if the user navigates to a different cycle.
    private var cycleStartString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        return formatter.string(from: cycle.start)
    }

    private func loadSummary() async {
        isLoading = true
        hasErrored = false
        do {
            summary = try await service.fetchSummary(
                cycle: cycle,
                categoriesById: categoriesById
            )
        } catch {
            #if DEBUG
            print("⚠️ CycleDetail load failed: \(error)")
            #endif
            summary = nil
            hasErrored = true
        }
        isLoading = false
    }

    /// Skeleton matches web's loading state — period-label rectangle plus
    /// 3 card-sized blocks for hero, math, and breakdowns.
    @ViewBuilder
    private var loadingSkeleton: some View {
        VStack(alignment: .leading, spacing: SikaTheme.Spacing.md) {
            RoundedRectangle(cornerRadius: 8)
                .fill(SikaTheme.Color.muted)
                .frame(width: 128, height: 16)

            RoundedRectangle(cornerRadius: 16)
                .fill(SikaTheme.Color.muted)
                .frame(height: 96)

            RoundedRectangle(cornerRadius: 16)
                .fill(SikaTheme.Color.muted)
                .frame(height: 160)

            RoundedRectangle(cornerRadius: 16)
                .fill(SikaTheme.Color.muted)
                .frame(height: 160)
        }
    }
}
