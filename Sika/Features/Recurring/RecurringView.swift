import SwiftUI

/// Phase REC_1 — Recurring tab UI.
/// Wraps in NavigationStack at the call site (AuthenticatedRootView) so the
/// detail page push works.
struct RecurringView: View {
    @Environment(AppState.self) private var appState
    @Environment(ToastManager.self) private var toasts

    @State private var showFormSheet = false
    @State private var editingItem: RecurringTransaction? = nil
    @State private var templateDefaults: QuickTemplate? = nil
    @State private var deletingItem: RecurringTransaction? = nil
    @State private var navigatedRecurring: RecurringTransaction? = nil

    private let goldColor = Color(hex: 0xD4A017)
    private let darkText = Color(hex: 0x0E1A2E)

    var body: some View {
        @Bindable var appStateBindable = appState

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                introHint
                RecurringTabsView(
                    selected: $appStateBindable.recurringTab,
                    recurringCount: appState.expenseRecurrings.count,
                    pausedCount: appState.pausedRecurrings.count
                )
                listContent
                if appState.recurringTab == .expense {
                    QuickTemplatesStrip(onTemplateTap: openWithTemplate)
                        .padding(.top, 8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 100)
        }
        .background(SikaTheme.Color.background)
        .navigationDestination(item: $navigatedRecurring) { recurring in
            RecurringDetailView(recurring: recurring)
        }
        .sheet(isPresented: $showFormSheet) {
            RecurringFormSheet(
                editingItem: editingItem,
                templateDefaults: templateDefaults,
                accounts: appState.accounts,
                categories: appState.categories,
                onSaved: {
                    await appState.reloadRecurringsAfterFormSave()
                }
            )
        }
        .alert(
            "Delete this recurring transaction?",
            isPresented: Binding(
                get: { deletingItem != nil },
                set: { if !$0 { deletingItem = nil } }
            ),
            presenting: deletingItem
        ) { item in
            Button("Cancel", role: .cancel) { deletingItem = nil }
            Button("Delete", role: .destructive) {
                Task {
                    let ok = await appState.deleteRecurring(item.id)
                    if ok { toasts.show("Deleted", kind: .success) }
                    else { toasts.show("Failed to delete", kind: .error) }
                    deletingItem = nil
                }
            }
        } message: { _ in
            Text("Already-generated transactions are kept.")
        }
        .task {
            if appState.recurringList.isEmpty && !appState.recurringLoading {
                await appState.loadRecurrings()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            Text("Recurring")
                .font(SikaTheme.Typography.sans(28, weight: .bold))
                .foregroundStyle(SikaTheme.Color.foreground)

            Spacer()

            syncButton

            Button {
                openCreate()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                    Text("Add")
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

    // MARK: - Intro hint

    /// iOS 17 doesn't support `.symbolEffect(.rotate, ...)` — that's iOS 18.
    /// Use a SwiftUI rotation effect with repeating animation instead.
    @ViewBuilder
    private var syncButton: some View {
        Button {
            Task { await appState.syncRecurringNow() }
        } label: {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(SikaTheme.Color.mutedForeground)
                .frame(width: 36, height: 36)
                .rotationEffect(.degrees(appState.recurringSyncing ? 360 : 0))
                .animation(
                    appState.recurringSyncing
                        ? .linear(duration: 1).repeatForever(autoreverses: false)
                        : .default,
                    value: appState.recurringSyncing
                )
                .background(SikaTheme.Color.card)
                .clipShape(Circle())
                .overlay(Circle().stroke(SikaTheme.Color.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Sync recurrings")
    }

    private var introHint: some View {
        HintCard(
            hintId: .recurringIntro,
            title: "Automate your money rhythm",
            message: "Track rent, subscriptions, and bills here. Auto-log handles the routine; nudges keep you in control."
        )
    }

    // MARK: - List

    @ViewBuilder
    private var listContent: some View {
        if appState.recurringLoading && appState.recurringList.isEmpty {
            skeleton
        } else {
            let items = currentTabItems
            if items.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(items) { recurring in
                        RecurringCardView(
                            recurring: recurring,
                            currencyCode: appState.currencyCode,
                            onOpenDetail: { navigatedRecurring = recurring },
                            onTogglePause: {
                                Task {
                                    await appState.togglePaused(recurring)
                                    toasts.show(
                                        recurring.isPaused ? "Resumed" : "Paused",
                                        kind: .success
                                    )
                                }
                            },
                            onEdit: { openEdit(recurring) },
                            onDelete: { deletingItem = recurring }
                        )
                    }
                }
            }
        }
    }

    private var currentTabItems: [RecurringTransaction] {
        switch appState.recurringTab {
        case .expense: return appState.expenseRecurrings
        case .paused:  return appState.pausedRecurrings
        }
    }

    private var skeleton: some View {
        VStack(spacing: 10) {
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 16)
                    .fill(SikaTheme.Color.muted)
                    .frame(height: 120)
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 32))
                .foregroundStyle(SikaTheme.Color.mutedForeground.opacity(0.6))
            Text(emptyText)
                .font(SikaTheme.Typography.sans(13))
                .foregroundStyle(SikaTheme.Color.mutedForeground)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            if appState.recurringTab == .expense {
                Button {
                    openCreate()
                } label: {
                    Text("Add expense")
                        .font(SikaTheme.Typography.sans(13, weight: .semibold))
                        .foregroundStyle(darkText)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(goldColor)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
        .padding(.bottom, 40)
    }

    private var emptyText: String {
        switch appState.recurringTab {
        case .expense:
            return "No recurring expenses yet. Add things like rent, subscriptions, or bills."
        case .paused:
            return "Nothing paused right now."
        }
    }

    // MARK: - Sheet openers

    private func openCreate() {
        editingItem = nil
        templateDefaults = nil
        showFormSheet = true
    }

    private func openEdit(_ recurring: RecurringTransaction) {
        editingItem = recurring
        templateDefaults = nil
        showFormSheet = true
    }

    private func openWithTemplate(_ template: QuickTemplate) {
        editingItem = nil
        templateDefaults = template
        showFormSheet = true
    }
}
