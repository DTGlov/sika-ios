import SwiftUI

/// Phase Goals T1 — Goals tab orchestrator.
/// Wraps in NavigationStack at the call site (AuthenticatedRootView) so the
/// detail page push works.
struct GoalsView: View {
    @Environment(AppState.self) private var appState
    @Environment(ToastManager.self) private var toasts

    @State private var navigatedGoal: Goal? = nil
    @State private var showFormSheet = false
    @State private var editingGoal: Goal? = nil
    @State private var showContributeSheet = false
    @State private var contributeTarget: Goal? = nil
    @State private var showNextCycleSheet = false
    @State private var nextCycleTarget: Goal? = nil

    private let goldColor = Color(hex: 0xD4A017)
    private let darkText = Color(hex: 0x0E1A2E)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                if appState.goalsLoading && appState.goalsList.isEmpty {
                    skeleton
                } else if appState.activeGoals.isEmpty && appState.completedGoals.isEmpty {
                    emptyState
                } else {
                    listContent
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 100)
        }
        .background(SikaTheme.Color.background)
        .navigationDestination(item: $navigatedGoal) { goal in
            GoalDetailView(goalId: goal.id)
        }
        .sheet(isPresented: $showFormSheet) {
            GoalFormSheet(
                editingGoal: editingGoal,
                accounts: appState.accounts,
                onSaved: { /* AppState reload happens inside */ }
            )
        }
        .sheet(isPresented: $showContributeSheet) {
            if let goal = contributeTarget {
                ContributeSheet(
                    goal: goal,
                    progress: appState.goalsProgressMap[goal.id],
                    onContributed: { /* AppState reload happens inside */ }
                )
            }
        }
        .sheet(isPresented: $showNextCycleSheet) {
            if let goal = nextCycleTarget {
                NextCycleSheet(
                    completedGoal: goal,
                    onStarted: { newGoal in
                        navigatedGoal = newGoal
                    }
                )
            }
        }
        .task {
            if appState.goalsList.isEmpty && !appState.goalsLoading {
                await appState.loadGoalsList()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Goals")
                    .font(SikaTheme.Typography.sans(28, weight: .bold))
                    .foregroundStyle(SikaTheme.Color.foreground)
                if !appState.activeGoals.isEmpty {
                    Text("\(CurrencyFormatter.format(appState.totalSavedAcrossActiveGoals, code: appState.currencyCode)) saved across \(appState.activeGoals.count) goal\(appState.activeGoals.count == 1 ? "" : "s")")
                        .font(SikaTheme.Typography.sans(12))
                        .foregroundStyle(SikaTheme.Color.mutedForeground)
                }
            }
            Spacer()
            Button {
                editingGoal = nil
                showFormSheet = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                    Text("New Goal")
                        .font(SikaTheme.Typography.sans(13, weight: .semibold))
                }
                .foregroundStyle(darkText)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(goldColor)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - List content

    private var listContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !appState.activeGoals.isEmpty {
                LazyVStack(spacing: 10) {
                    ForEach(Array(appState.activeGoals.enumerated()), id: \.element.id) { _, progress in
                        cardRow(progress: progress)
                    }
                }
            }

            if !appState.completedGoals.isEmpty {
                Text("COMPLETED")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(SikaTheme.Color.mutedForeground)
                    .padding(.top, 8)
                LazyVStack(spacing: 10) {
                    ForEach(Array(appState.completedGoals.enumerated()), id: \.element.id) { _, progress in
                        cardRow(progress: progress)
                            .opacity(0.7)
                    }
                }
            }
        }
    }

    private func cardRow(progress: GoalProgress) -> some View {
        GoalCardView(
            progress: progress,
            currencyCode: appState.currencyCode,
            onOpenDetail: { navigatedGoal = progress.goal },
            onEdit: {
                editingGoal = progress.goal
                showFormSheet = true
            },
            onContribute: {
                contributeTarget = progress.goal
                showContributeSheet = true
            },
            onStartNextCycle: {
                nextCycleTarget = progress.goal
                showNextCycleSheet = true
            }
        )
    }

    // MARK: - Skeleton + empty

    private var skeleton: some View {
        VStack(spacing: 10) {
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 16)
                    .fill(SikaTheme.Color.muted)
                    .frame(height: 120)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            HintCard(
                hintId: .goalsIntro,
                title: "Set goals you'll hit",
                message: "Save for what matters — vacations, emergency funds, big purchases. Track progress and stay on pace."
            )

            VStack(spacing: 12) {
                Image(systemName: "target")
                    .font(.system(size: 40))
                    .foregroundStyle(SikaTheme.Color.mutedForeground.opacity(0.6))
                Text("No goals yet")
                    .font(SikaTheme.Typography.sans(15, weight: .semibold))
                    .foregroundStyle(SikaTheme.Color.foreground)
                Text("Pick one of these or create your own.")
                    .font(SikaTheme.Typography.sans(12))
                    .foregroundStyle(SikaTheme.Color.mutedForeground)

                SuggestionPillStrip {
                    editingGoal = nil
                    showFormSheet = true
                }
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 20)
        }
    }
}
