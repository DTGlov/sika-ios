import SwiftUI

/// Per-goal detail page. Hero card + stat grid + contributions + payments
/// (read-only in T1) + Add Contribution / Start Next Cycle CTA.
struct GoalDetailView: View {
    let goalId: UUID

    @Environment(AppState.self) private var appState
    @Environment(ToastManager.self) private var toasts
    @Environment(\.dismiss) private var dismiss

    @State private var contributions: [TransactionListRow] = []
    @State private var payments: [TransactionListRow] = []
    @State private var previousCycle: Goal? = nil
    @State private var detailLoading: Bool = false

    @State private var showEditSheet = false
    @State private var showContributeSheet = false
    @State private var showNextCycleSheet = false
    @State private var showArchiveAlert = false
    @State private var showDeleteAlert = false

    private let goldColor = Color(hex: 0xD4A017)
    private let darkText = Color(hex: 0x0E1A2E)
    private let greenColor = Color(hex: 0x00D9A3)
    private let orangeColor = Color(hex: 0xF97316)

    private var progress: GoalProgress? { appState.goalsProgressMap[goalId] }
    private var goal: Goal? { progress?.goal }
    private var accentColor: Color {
        guard let g = goal else { return greenColor }
        return GoalConstants.resolveColor(g.color)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let prev = previousCycle {
                    backlinkRow(previousCycle: prev)
                }
                if let g = goal, let p = progress {
                    heroCard(goal: g, progress: p)
                    statsGrid(goal: g, progress: p)
                    ctaButtons(goal: g)
                    if !contributions.isEmpty {
                        sectionHeader("CONTRIBUTIONS")
                        transactionsList(contributions)
                    }
                    if g.goalType == .target && !payments.isEmpty {
                        sectionHeader("PAYMENTS")
                        transactionsList(payments)
                    }
                } else if detailLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                } else {
                    Text("Goal not found.")
                        .font(SikaTheme.Typography.sans(13))
                        .foregroundStyle(SikaTheme.Color.mutedForeground)
                        .padding(.top, 60)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(SikaTheme.Color.background)
        .navigationTitle(goal?.name ?? "Goal")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarItems }
        .sheet(isPresented: $showEditSheet) {
            if let g = goal {
                GoalFormSheet(
                    editingGoal: g,
                    accounts: appState.accounts,
                    onSaved: { /* AppState reload happens inside */ }
                )
            }
        }
        .sheet(isPresented: $showContributeSheet) {
            if let g = goal {
                ContributeSheet(
                    goal: g,
                    progress: progress,
                    onContributed: { await loadDetail() }
                )
            }
        }
        .sheet(isPresented: $showNextCycleSheet) {
            if let g = goal {
                NextCycleSheet(
                    completedGoal: g,
                    onStarted: { _ in dismiss() }
                )
            }
        }
        .alert(
            "Archive this goal?",
            isPresented: $showArchiveAlert
        ) {
            Button("Cancel", role: .cancel) { }
            Button("Archive", role: .destructive) {
                Task { await handleArchive() }
            }
        } message: {
            Text("It won't appear in your list. Contributions stay as transactions.")
        }
        .alert(
            "Delete this goal permanently?",
            isPresented: $showDeleteAlert
        ) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task { await handleDelete() }
            }
        } message: {
            Text("Contributions stay as transactions. This can't be undone.")
        }
        .task { await loadDetail() }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button {
                    showEditSheet = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                Button {
                    showArchiveAlert = true
                } label: {
                    Label("Archive", systemImage: "archivebox")
                }
                Button(role: .destructive) {
                    showDeleteAlert = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 17))
            }
        }
    }

    // MARK: - Hero

    private func heroCard(goal: Goal, progress: GoalProgress) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Text(goal.icon ?? GoalConstants.defaultIcon)
                    .font(.system(size: 32))
                    .frame(width: 60, height: 60)
                    .background(accentColor.opacity(0.20))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                VStack(alignment: .leading, spacing: 4) {
                    Text(goal.name)
                        .font(SikaTheme.Typography.sans(20, weight: .bold))
                        .foregroundStyle(SikaTheme.Color.foreground)
                    if let cycle = goal.cycleCount, cycle > 1 {
                        Text("Cycle \(cycle)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(accentColor)
                    }
                    if let desc = goal.description, !desc.isEmpty {
                        Text(desc)
                            .font(SikaTheme.Typography.sans(12))
                            .foregroundStyle(SikaTheme.Color.mutedForeground)
                            .lineLimit(3)
                    }
                }
                Spacer(minLength: 0)
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text(CurrencyFormatter.format(progress.currentAmount, code: appState.currencyCode))
                    .font(SikaTheme.Typography.sans(28, weight: .bold))
                    .foregroundStyle(accentColor)
                    .monospacedDigit()
                if let target = goal.targetAmount, goal.goalType == .target {
                    Text("of \(CurrencyFormatter.format(target, code: appState.currencyCode)) target")
                        .font(SikaTheme.Typography.sans(12))
                        .foregroundStyle(SikaTheme.Color.mutedForeground)
                        .monospacedDigit()
                } else if goal.goalType == .perpetual {
                    Text("Perpetual goal")
                        .font(SikaTheme.Typography.sans(12, weight: .semibold))
                        .foregroundStyle(accentColor)
                }
            }

            if goal.goalType == .target, let pct = progress.progressPercent {
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(SikaTheme.Color.muted)
                        .frame(height: 10)
                    GeometryReader { geo in
                        Capsule()
                            .fill(accentColor)
                            .frame(width: geo.size.width * CGFloat(pct / 100.0), height: 10)
                            .animation(.spring(response: 0.6, dampingFraction: 0.85), value: pct)
                    }
                    .frame(height: 10)
                }
                Text("\(Int(pct.rounded()))% complete")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(accentColor)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(accentColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(accentColor.opacity(0.30), lineWidth: 1)
        )
    }

    // MARK: - Stats grid

    private func statsGrid(goal: Goal, progress: GoalProgress) -> some View {
        let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
        let isCompleted = goal.completedAt != nil

        return LazyVGrid(columns: columns, spacing: 8) {
            if let dr = progress.daysRemaining, !isCompleted {
                StatTile(label: "Days left", value: "\(dr)d")
            }
            if let pace = progress.requiredMonthlyPace, !isCompleted {
                StatTile(
                    label: "Monthly pace",
                    value: CurrencyFormatter.format(pace, code: appState.currencyCode)
                )
            }
            if let onTrack = progress.isOnTrack, !isCompleted {
                StatTile(
                    label: "Status",
                    value: onTrack ? "On Track" : "Behind",
                    color: onTrack ? greenColor : orangeColor
                )
            }
            if isCompleted, let completedAt = goal.completedAt {
                StatTile(label: "Completed", value: shortDate(completedAt))
            }
            StatTile(label: "Contributions", value: "\(contributions.count)")
            if goal.goalType == .target {
                StatTile(label: "Payments", value: "\(payments.count)")
            }
            if let acc = progress.fundingAccount {
                StatTile(label: "Save to", value: acc.name)
            }
        }
    }

    // MARK: - CTA

    @ViewBuilder
    private func ctaButtons(goal: Goal) -> some View {
        if goal.completedAt != nil && goal.goalType == .target {
            Button {
                showNextCycleSheet = true
            } label: {
                HStack(spacing: 6) {
                    Text("Start next cycle")
                    Image(systemName: "arrow.right")
                }
                .font(SikaTheme.Typography.sans(15, weight: .semibold))
                .foregroundStyle(darkText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        } else if goal.completedAt == nil {
            Button {
                showContributeSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                    Text("Add Contribution")
                }
                .font(SikaTheme.Typography.sans(15, weight: .semibold))
                .foregroundStyle(darkText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Backlink

    private func backlinkRow(previousCycle: Goal) -> some View {
        Button {
            // Navigation to previous cycle requires a navigationPath push;
            // T1 leaves this as a visible-only chip and dismisses to the
            // list via the back button if the user wants to go up. Wire as
            // an in-list NavigationLink in T2.
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 11))
                Text("Previous cycle: \(previousCycle.name)")
                    .font(SikaTheme.Typography.sans(11, weight: .semibold))
            }
            .foregroundStyle(SikaTheme.Color.mutedForeground)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(SikaTheme.Color.muted)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Sections

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .tracking(1.5)
            .foregroundStyle(SikaTheme.Color.mutedForeground)
            .padding(.top, 8)
    }

    private func transactionsList(_ rows: [TransactionListRow]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                transactionRow(row)
                if index < rows.count - 1 {
                    Divider().padding(.leading, 16)
                }
            }
        }
        .background(SikaTheme.Color.card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(SikaTheme.Color.border, lineWidth: 1)
        )
    }

    private func transactionRow(_ row: TransactionListRow) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(row.note ?? row.category?.name ?? "Transfer")
                    .font(SikaTheme.Typography.sans(13, weight: .semibold))
                    .foregroundStyle(SikaTheme.Color.foreground)
                    .lineLimit(1)
                Text(row.transactionDate)
                    .font(SikaTheme.Typography.sans(11))
                    .foregroundStyle(SikaTheme.Color.mutedForeground)
            }
            Spacer()
            Text(CurrencyFormatter.format(row.amount, code: appState.currencyCode))
                .font(SikaTheme.Typography.sans(13, weight: .bold))
                .foregroundStyle(SikaTheme.Color.foreground)
                .monospacedDigit()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - Lifecycle

    private func loadDetail() async {
        detailLoading = true
        defer { detailLoading = false }
        let service = GoalService()

        // Make sure base list is loaded so progress map is populated.
        if appState.goalsProgressMap[goalId] == nil {
            await appState.loadGoalsList()
        }

        do {
            async let contribs = service.fetchContributions(goalId: goalId)
            async let pays = service.fetchPayments(goalId: goalId)
            self.contributions = (try? await contribs) ?? []
            self.payments = (try? await pays) ?? []
        }

        if let prevId = goal?.previousGoalId {
            self.previousCycle = try? await service.fetchPreviousCycle(previousGoalId: prevId)
        } else {
            self.previousCycle = nil
        }
    }

    private func handleArchive() async {
        let ok = await appState.archiveGoal(goalId)
        if ok {
            toasts.show("Goal archived", kind: .success)
            dismiss()
        } else {
            toasts.show("Failed to archive", kind: .error)
        }
    }

    private func handleDelete() async {
        let ok = await appState.deleteGoal(goalId)
        if ok {
            toasts.show("Goal deleted", kind: .success)
            dismiss()
        } else {
            toasts.show("Failed to delete", kind: .error)
        }
    }

    private func shortDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f.string(from: date)
    }
}
