import SwiftUI

/// Categories section.
/// S1 shipped read-only grouped render with Add/Edit/Archive disabled.
/// S3 wires the full CRUD: tap row → edit, archive icon → soft archive,
/// Restore link in the Archived collapsible → restore, top-level "+ Add"
/// → create form.
///
/// Render groups (audit Section 11.6):
///   1. NEEDS    (green #00D9A3) — expense + bucket=needs
///   2. WANTS    (yellow #FBBF24) — expense + bucket=wants
///   3. SAVINGS  (blue #60A5FA)   — expense + bucket=savings
///   4. Spending (no bucket)      — expense + bucket=null
///   5. INCOME   (gold #D4A017)
///   6. ADJUSTMENTS               — type=adjustment
///   7. Archived (collapsible)    — any type with archived=true
struct CategoriesSection: View {
    @Environment(AppState.self) private var appState
    @Environment(ToastManager.self) private var toasts

    @State private var archivedExpanded = false
    @State private var presentingNewForm: Bool = false
    @State private var editingCategory: TransactionCategory? = nil
    @State private var pendingArchive: TransactionCategory? = nil

    private let goldColor = Color(hex: 0xD4A017)

    var body: some View {
        SettingsCard(
            title: "Categories",
            subtitle: "Group your spending. Add and archive categories to fit your life."
        ) {
            VStack(alignment: .leading, spacing: 14) {
                addButton

                ForEach(activeGroupings, id: \.label) { group in
                    groupView(group)
                }

                if !archivedItems.isEmpty {
                    archivedToggle
                    if archivedExpanded {
                        ForEach(archivedItems) { cat in
                            archivedRow(cat)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $presentingNewForm) {
            CategoryFormSheet(
                editingCategory: nil,
                buckets: appState.budgetBuckets,
                onSaved: {}
            )
        }
        .sheet(item: $editingCategory) { cat in
            CategoryFormSheet(
                editingCategory: cat,
                buckets: appState.budgetBuckets,
                onSaved: {}
            )
        }
        .alert(
            archiveAlertTitle,
            isPresented: Binding(
                get: { pendingArchive != nil },
                set: { if !$0 { pendingArchive = nil } }
            ),
            presenting: pendingArchive
        ) { cat in
            Button("Cancel", role: .cancel) { pendingArchive = nil }
            Button("Archive") {
                let target = cat
                pendingArchive = nil
                Task { await performArchive(target) }
            }
        } message: { _ in
            Text("You can restore it later from the Archived section.")
        }
    }

    // MARK: - Data slicing

    private var allCategories: [TransactionCategory] { appState.categories }
    private var activeCategories: [TransactionCategory] { allCategories.filter { $0.archived != true } }
    private var archivedItems: [TransactionCategory] {
        allCategories.filter { $0.archived == true }
            .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }

    private var bucketIdToName: [UUID: String] {
        Dictionary(uniqueKeysWithValues: appState.budgetBuckets.map {
            ($0.id, $0.name.lowercased())
        })
    }

    private struct Grouping {
        let label: String
        let color: Color
        let items: [TransactionCategory]
        let isMuted: Bool
    }

    private var activeGroupings: [Grouping] {
        let needs = activeCategories.filter {
            $0.categoryType == .expense && bucketName(for: $0) == "needs"
        }
        let wants = activeCategories.filter {
            $0.categoryType == .expense && bucketName(for: $0) == "wants"
        }
        let savings = activeCategories.filter {
            $0.categoryType == .expense && bucketName(for: $0) == "savings"
        }
        let noBucket = activeCategories.filter {
            $0.categoryType == .expense && bucketName(for: $0) == nil
        }
        let income = activeCategories.filter { $0.categoryType == .income }
        let adjustments = activeCategories.filter { $0.categoryType == .adjustment }

        var groups: [Grouping] = []
        if !needs.isEmpty {
            groups.append(.init(label: "NEEDS", color: Color(hex: 0x00D9A3), items: needs, isMuted: false))
        }
        if !wants.isEmpty {
            groups.append(.init(label: "WANTS", color: Color(hex: 0xFBBF24), items: wants, isMuted: false))
        }
        if !savings.isEmpty {
            groups.append(.init(label: "SAVINGS", color: Color(hex: 0x60A5FA), items: savings, isMuted: false))
        }
        if !noBucket.isEmpty {
            groups.append(.init(
                label: "SPENDING (NO BUCKET)",
                color: SikaTheme.Color.mutedForeground,
                items: noBucket,
                isMuted: true
            ))
        }
        if !income.isEmpty {
            groups.append(.init(label: "INCOME", color: goldColor, items: income, isMuted: false))
        }
        if !adjustments.isEmpty {
            groups.append(.init(
                label: "ADJUSTMENTS",
                color: SikaTheme.Color.mutedForeground,
                items: adjustments,
                isMuted: true
            ))
        }
        return groups
    }

    private func bucketName(for category: TransactionCategory) -> String? {
        guard let bid = category.bucketId else { return nil }
        return bucketIdToName[bid]
    }

    private var archiveAlertTitle: String {
        if let cat = pendingArchive {
            return "Archive “\(cat.name)”?"
        }
        return "Archive category?"
    }

    // MARK: - UI

    private var addButton: some View {
        Button {
            presentingNewForm = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                Text("Add category")
            }
            .font(SikaTheme.Typography.sans(13, weight: .semibold))
            .foregroundStyle(goldColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(goldColor.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private func groupView(_ group: Grouping) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle()
                    .fill(group.color)
                    .frame(width: 6, height: 6)
                Text(group.label)
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(group.color)
            }
            ForEach(group.items) { cat in
                row(cat, mutedLabel: group.isMuted)
            }
        }
    }

    private func row(_ category: TransactionCategory, mutedLabel: Bool) -> some View {
        Button {
            editingCategory = category
        } label: {
            HStack(spacing: 10) {
                Text(IconResolver.resolve(category.icon))
                    .font(.system(size: 16))
                    .frame(width: 28, height: 28)
                    .background(SikaTheme.Color.muted)
                    .clipShape(Circle())
                Text(category.name)
                    .font(SikaTheme.Typography.sans(13))
                    .foregroundStyle(mutedLabel ? SikaTheme.Color.mutedForeground : SikaTheme.Color.foreground)
                Spacer()
                Button {
                    pendingArchive = category
                } label: {
                    Image(systemName: "archivebox")
                        .font(.system(size: 12))
                        .foregroundStyle(SikaTheme.Color.mutedForeground)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func archivedRow(_ category: TransactionCategory) -> some View {
        HStack(spacing: 10) {
            Text(IconResolver.resolve(category.icon))
                .font(.system(size: 14))
                .frame(width: 28, height: 28)
                .background(SikaTheme.Color.muted)
                .clipShape(Circle())
            Text(category.name)
                .font(SikaTheme.Typography.sans(13))
                .foregroundStyle(SikaTheme.Color.mutedForeground)
                .strikethrough()
            Spacer()
            Button {
                Task { await performRestore(category) }
            } label: {
                Text("Restore")
                    .font(SikaTheme.Typography.sans(11, weight: .semibold))
                    .foregroundStyle(goldColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(goldColor.opacity(0.10))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .opacity(0.5)
    }

    private var archivedToggle: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { archivedExpanded.toggle() }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: archivedExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                Text("Archived (\(archivedItems.count))")
                    .font(SikaTheme.Typography.sans(12, weight: .semibold))
            }
            .foregroundStyle(SikaTheme.Color.mutedForeground)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func performArchive(_ category: TransactionCategory) async {
        let ok = await appState.archiveCategory(category.id)
        if ok {
            toasts.show("Category archived", kind: .success)
        } else {
            toasts.show("Failed to archive", kind: .error)
        }
    }

    private func performRestore(_ category: TransactionCategory) async {
        let ok = await appState.restoreCategory(category.id)
        if ok {
            toasts.show("Restored", kind: .success)
        } else {
            toasts.show("Failed to restore", kind: .error)
        }
    }
}
