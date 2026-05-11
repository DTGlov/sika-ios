import SwiftUI

/// Bottom sheet for creating or editing a category.
/// Field order mirrors audit Section 11.2:
///   1. Type chips (Expense / Income / Adjustment)
///   2. Bucket chips (conditional — only shown when type=.expense)
///   3. Name (required, max 60 chars)
///   4. Icon picker (23-emoji grid)
///   5. Submit
///
/// Bucket-coupling rule (Section 11.4):
/// - type = .expense → bucket can be Needs / Wants / Savings / None
/// - type = .income → bucket forced to nil (picker hidden)
/// - type = .adjustment → bucket forced to nil (picker hidden)
struct CategoryFormSheet: View {
    /// nil = create; non-nil = edit
    let editingCategory: TransactionCategory?
    let buckets: [BudgetBucket]
    let onSaved: () async -> Void

    @Environment(AppState.self) private var appState
    @Environment(ToastManager.self) private var toasts
    @Environment(\.dismiss) private var dismiss

    // Form state
    @State private var name: String = ""
    @State private var type: CategoryType = .expense
    @State private var bucketId: UUID? = nil
    @State private var icon: String = CategoryEmojis.defaultEmoji

    @State private var isSubmitting = false

    private let goldColor = Color(hex: 0xD4A017)
    private let darkText = Color(hex: 0x0E1A2E)

    private var isEditing: Bool { editingCategory != nil }
    private var titleText: String { isEditing ? "Edit category" : "New category" }
    private var submitLabel: String { isEditing ? "Save changes" : "Create" }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSubmit: Bool {
        guard !isSubmitting else { return false }
        guard !trimmedName.isEmpty, trimmedName.count <= 60 else { return false }
        return true
    }

    private var bucketByName: [String: BudgetBucket] {
        Dictionary(uniqueKeysWithValues: buckets.map { ($0.name.lowercased(), $0) })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    typeSection
                    if type == .expense {
                        bucketSection
                    }
                    nameField
                    iconField
                    submitButton
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .navigationTitle(titleText)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .background(SikaTheme.Color.background)
        }
        .presentationDetents([.large])
        .onAppear { primeFromInputs() }
    }

    // MARK: - Fields

    private var typeSection: some View {
        FieldLabel("Type") {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3),
                spacing: 8
            ) {
                ForEach(CategoryType.allCases) { t in
                    typeChip(t)
                }
            }
        }
    }

    private func typeChip(_ t: CategoryType) -> some View {
        let greenColor = Color(hex: 0x00D9A3)
        let isActive = (type == t)
        return Button {
            if type != t {
                type = t
                // Bucket-coupling: leaving expense always clears the bucket.
                if t != .expense { bucketId = nil }
            }
        } label: {
            Text(t.displayLabel)
                .font(SikaTheme.Typography.sans(13, weight: isActive ? .semibold : .regular))
                .foregroundStyle(isActive ? greenColor : SikaTheme.Color.foreground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isActive ? greenColor.opacity(0.10) : SikaTheme.Color.card)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            isActive ? greenColor : SikaTheme.Color.border,
                            lineWidth: isActive ? 1.5 : 1
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private var bucketSection: some View {
        FieldLabel("Bucket") {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2),
                spacing: 8
            ) {
                bucketChip(name: "Needs",   color: Color(hex: 0x00D9A3), nameKey: "needs")
                bucketChip(name: "Wants",   color: Color(hex: 0xFBBF24), nameKey: "wants")
                bucketChip(name: "Savings", color: Color(hex: 0x60A5FA), nameKey: "savings")
                noneBucketChip()
            }
        }
    }

    private func bucketChip(name: String, color: Color, nameKey: String) -> some View {
        let bucket = bucketByName[nameKey]
        let isActive = (bucketId != nil && bucket?.id == bucketId)
        return Button {
            bucketId = bucket?.id
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text(name)
                    .font(SikaTheme.Typography.sans(13, weight: isActive ? .semibold : .regular))
                    .foregroundStyle(isActive ? color : SikaTheme.Color.foreground)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isActive ? color.opacity(0.10) : SikaTheme.Color.card)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        isActive ? color : SikaTheme.Color.border,
                        lineWidth: isActive ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(bucket == nil)
    }

    private func noneBucketChip() -> some View {
        let isActive = (bucketId == nil)
        return Button {
            bucketId = nil
        } label: {
            Text("None")
                .font(SikaTheme.Typography.sans(13, weight: isActive ? .semibold : .regular))
                .foregroundStyle(isActive ? SikaTheme.Color.foreground : SikaTheme.Color.mutedForeground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isActive ? SikaTheme.Color.muted : SikaTheme.Color.card)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            isActive ? SikaTheme.Color.mutedForeground : SikaTheme.Color.border,
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private var nameField: some View {
        FieldLabel("Name") {
            TextField("e.g. Groceries", text: $name)
                .font(SikaTheme.Typography.sans(15))
                .textInputAutocapitalization(.words)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(SikaTheme.Color.card)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(SikaTheme.Color.border, lineWidth: 1)
                )
                .onChange(of: name) { _, newValue in
                    if newValue.count > 60 { name = String(newValue.prefix(60)) }
                }
        }
    }

    private var iconField: some View {
        FieldLabel("Icon") {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6),
                spacing: 8
            ) {
                ForEach(CategoryEmojis.all, id: \.self) { emoji in
                    iconButton(emoji)
                }
            }
        }
    }

    private func iconButton(_ emoji: String) -> some View {
        let isActive = (icon == emoji)
        return Button {
            icon = emoji
        } label: {
            Text(emoji)
                .font(.system(size: 22))
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(isActive ? goldColor.opacity(0.15) : SikaTheme.Color.card)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            isActive ? goldColor : SikaTheme.Color.border,
                            lineWidth: isActive ? 1.5 : 1
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private var submitButton: some View {
        Button {
            Task { await submit() }
        } label: {
            HStack {
                if isSubmitting {
                    ProgressView().scaleEffect(0.85).tint(darkText)
                }
                Text(submitLabel)
                    .font(SikaTheme.Typography.sans(15, weight: .semibold))
                    .foregroundStyle(canSubmit ? darkText : SikaTheme.Color.mutedForeground)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(canSubmit ? goldColor : SikaTheme.Color.muted)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(!canSubmit)
        .padding(.top, 8)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func FieldLabel<Content: View>(
        _ label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(SikaTheme.Typography.sans(12, weight: .semibold))
                .foregroundStyle(SikaTheme.Color.foreground)
            content()
        }
    }

    // MARK: - Pre-fill + submit

    private func primeFromInputs() {
        if let cat = editingCategory {
            name = cat.name
            type = cat.categoryType
            bucketId = cat.bucketId
            icon = IconResolver.resolveOrNil(cat.icon) ?? CategoryEmojis.defaultEmoji
        }
    }

    private func submit() async {
        guard canSubmit else { return }

        isSubmitting = true
        defer { isSubmitting = false }

        // Bucket-coupling safety net: if the user managed to leave bucketId
        // set after switching off expense, clear it before sending.
        let resolvedBucketId: UUID? = (type == .expense) ? bucketId : nil

        let success: Bool
        if let editing = editingCategory {
            success = await appState.updateCategory(
                id: editing.id,
                name: trimmedName,
                type: type,
                icon: icon,
                bucketId: resolvedBucketId
            )
        } else {
            success = await appState.createCategory(
                name: trimmedName,
                type: type,
                icon: icon,
                bucketId: resolvedBucketId
            )
        }

        if success {
            toasts.show(isEditing ? "Category updated" : "Category created", kind: .success)
            await onSaved()
            dismiss()
        } else {
            toasts.show("Failed to save", kind: .error)
        }
    }
}
