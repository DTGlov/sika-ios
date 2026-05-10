import SwiftUI

/// Read-only Categories section. S3 wires the CRUD form sheet.
/// Groups by NEEDS / WANTS / SAVINGS / INCOME / Adjustments. Archived
/// categories appear in a collapsible footer at half opacity.
struct CategoriesSection: View {
    @Environment(AppState.self) private var appState
    @Environment(ToastManager.self) private var toasts

    @State private var archivedExpanded = false

    var body: some View {
        SettingsCard(
            title: "Categories",
            subtitle: "Group your spending. Add and archive categories to fit your life."
        ) {
            VStack(alignment: .leading, spacing: 14) {
                addButton

                ForEach(activeGroupings, id: \.0) { group in
                    groupView(label: group.0, color: group.1, items: group.2)
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
    }

    private var allCategories: [TransactionCategory] { appState.categories }
    private var activeCategories: [TransactionCategory] { allCategories.filter { $0.archived != true } }
    private var archivedItems: [TransactionCategory] { allCategories.filter { $0.archived == true } }

    private var bucketIdToName: [UUID: String] {
        Dictionary(uniqueKeysWithValues: appState.budgetBuckets.map {
            ($0.id, $0.name.lowercased())
        })
    }

    /// Returns label, color, items per group — in display order.
    private var activeGroupings: [(String, Color, [TransactionCategory])] {
        let needs = activeCategories.filter {
            $0.categoryType == .expense && bucketName(for: $0) == "needs"
        }
        let wants = activeCategories.filter {
            $0.categoryType == .expense && bucketName(for: $0) == "wants"
        }
        let savings = activeCategories.filter {
            $0.categoryType == .expense && bucketName(for: $0) == "savings"
        }
        let income = activeCategories.filter { $0.categoryType == .income }
        let adjustments = activeCategories.filter { $0.categoryType == .adjustment }

        var groups: [(String, Color, [TransactionCategory])] = []
        if !needs.isEmpty   { groups.append(("NEEDS",   Color(hex: 0x00D9A3), needs)) }
        if !wants.isEmpty   { groups.append(("WANTS",   Color(hex: 0xFBBF24), wants)) }
        if !savings.isEmpty { groups.append(("SAVINGS", Color(hex: 0x60A5FA), savings)) }
        if !income.isEmpty  { groups.append(("INCOME",  Color(hex: 0xD4A017), income)) }
        if !adjustments.isEmpty {
            groups.append(("ADJUSTMENTS", SikaTheme.Color.mutedForeground, adjustments))
        }
        return groups
    }

    private func bucketName(for category: TransactionCategory) -> String? {
        guard let bid = category.bucketId else { return nil }
        return bucketIdToName[bid]
    }

    private var addButton: some View {
        Button {
            toasts.show("Adding categories coming soon", kind: .info)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                Text("Add category")
            }
            .font(SikaTheme.Typography.sans(13, weight: .semibold))
            .foregroundStyle(SikaTheme.Color.mutedForeground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(SikaTheme.Color.muted)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .opacity(0.6)
    }

    private func groupView(
        label: String,
        color: Color,
        items: [TransactionCategory]
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(color)
            }
            ForEach(items) { cat in
                row(cat)
            }
        }
    }

    private func row(_ category: TransactionCategory) -> some View {
        HStack(spacing: 10) {
            Text(IconResolver.resolve(category.icon))
                .font(.system(size: 16))
                .frame(width: 28, height: 28)
                .background(SikaTheme.Color.muted)
                .clipShape(Circle())
            Text(category.name)
                .font(SikaTheme.Typography.sans(13))
                .foregroundStyle(SikaTheme.Color.foreground)
            Spacer()
            HStack(spacing: 0) {
                disabledIcon("pencil")
                disabledIcon("archivebox")
            }
            .opacity(0.4)
        }
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
                toasts.show("Restore coming soon", kind: .info)
            } label: {
                Text("Restore")
                    .font(SikaTheme.Typography.sans(11, weight: .semibold))
                    .foregroundStyle(Color(hex: 0xD4A017))
            }
            .buttonStyle(.plain)
            .opacity(0.6)
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
                Text("\(archivedItems.count) archived")
                    .font(SikaTheme.Typography.sans(12))
            }
            .foregroundStyle(SikaTheme.Color.mutedForeground)
        }
        .buttonStyle(.plain)
    }

    private func disabledIcon(_ name: String) -> some View {
        Button {
            toasts.show("Category editing coming soon", kind: .info)
        } label: {
            Image(systemName: name)
                .font(.system(size: 12))
                .foregroundStyle(SikaTheme.Color.mutedForeground)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
