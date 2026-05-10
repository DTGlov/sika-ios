import SwiftUI

/// Bottom sheet with filter sections (Type / Account / Bucket / Category /
/// Amount range / Sort) bound to a TransactionFilters binding.
struct TransactionFilterSheet: View {
    @Binding var filters: TransactionFilters
    let accounts: [Account]
    let categories: [TransactionCategory]
    let budgetBuckets: [BudgetBucket]
    @Environment(\.dismiss) private var dismiss

    private let goldColor = Color(hex: 0xD4A017)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    typeSection
                    if accounts.count > 1 { accountSection }
                    if hasBucketCategories { bucketSection }
                    categorySection
                    amountRangeSection
                    sortSection
                    if filters.activeFilterCount > 0 {
                        clearAllButton
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(goldColor)
                }
            }
            .background(SikaTheme.Color.background)
        }
        .presentationDetents([.large])
    }

    // MARK: - Sections

    private var typeSection: some View {
        FilterChipSection(title: "Type") {
            ChipButton(label: "All Types", isActive: filters.type == nil) {
                filters.type = nil
            }
            ForEach(TransactionType.allCases, id: \.self) { type in
                ChipButton(label: type.displayName, isActive: filters.type == type) {
                    filters.type = type
                }
            }
        }
    }

    private var accountSection: some View {
        FilterChipSection(title: "Account") {
            ChipButton(label: "All accounts", isActive: filters.accountId == nil) {
                filters.accountId = nil
            }
            ForEach(accounts.filter { $0.isActive != false }) { account in
                ChipButton(label: account.name, isActive: filters.accountId == account.id) {
                    filters.accountId = account.id
                }
            }
        }
    }

    private var hasBucketCategories: Bool {
        !budgetBuckets.isEmpty
    }

    private var bucketSection: some View {
        FilterChipSection(title: "Bucket") {
            ChipButton(label: "All Buckets", isActive: filters.bucket == nil) {
                filters.bucket = nil
            }
            ForEach(TransactionFilters.BucketName.allCases) { bucket in
                ChipButton(label: bucket.rawValue, isActive: filters.bucket == bucket) {
                    filters.bucket = bucket
                }
            }
        }
    }

    private var categorySection: some View {
        FilterChipSection(title: "Category") {
            ChipButton(label: "All categories", isActive: filters.categoryId == nil) {
                filters.categoryId = nil
            }
            ForEach(categories.filter { $0.archived != true }) { category in
                ChipButton(label: category.name, isActive: filters.categoryId == category.id) {
                    filters.categoryId = category.id
                }
            }
        }
    }

    private var amountRangeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Amount range")
                .font(SikaTheme.Typography.sans(13, weight: .semibold))
                .foregroundStyle(SikaTheme.Color.foreground)
            HStack(spacing: 8) {
                AmountInput(label: "Min", value: $filters.amountMin)
                Text("–")
                    .foregroundStyle(SikaTheme.Color.mutedForeground)
                AmountInput(label: "Max", value: $filters.amountMax)
            }
        }
    }

    private var sortSection: some View {
        FilterChipSection(title: "Sort") {
            ForEach(TransactionFilters.SortKey.allCases) { sort in
                ChipButton(label: sort.displayLabel, isActive: filters.sort == sort) {
                    filters.sort = sort
                }
            }
        }
    }

    private var clearAllButton: some View {
        Button {
            filters.clearAll()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "xmark.circle.fill")
                Text("Clear all filters")
            }
            .font(SikaTheme.Typography.sans(13, weight: .semibold))
            .foregroundStyle(goldColor)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Helpers

private struct FilterChipSection<Chips: View>: View {
    let title: String
    @ViewBuilder let chips: Chips

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(SikaTheme.Typography.sans(13, weight: .semibold))
                .foregroundStyle(SikaTheme.Color.foreground)
            FlowLayout(spacing: 6) {
                chips
            }
        }
    }
}

private struct ChipButton: View {
    let label: String
    let isActive: Bool
    let action: () -> Void

    private let goldColor = Color(hex: 0xD4A017)

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(SikaTheme.Typography.sans(12, weight: isActive ? .semibold : .regular))
                .foregroundStyle(isActive ? goldColor : SikaTheme.Color.mutedForeground)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    isActive ? goldColor.opacity(0.12) : SikaTheme.Color.muted
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(
                        isActive ? goldColor : Color.clear,
                        lineWidth: 1.5
                    )
                )
        }
        .buttonStyle(.plain)
    }
}

private struct AmountInput: View {
    let label: String
    @Binding var value: Decimal?
    @State private var text: String = ""

    var body: some View {
        HStack(spacing: 4) {
            Text("GHS")
                .font(SikaTheme.Typography.sans(11))
                .foregroundStyle(SikaTheme.Color.mutedForeground)
            TextField(label, text: $text)
                .font(SikaTheme.Typography.sans(13))
                .keyboardType(.decimalPad)
                .onChange(of: text) { _, newValue in
                    let trimmed = newValue.trimmingCharacters(in: .whitespaces)
                    if trimmed.isEmpty {
                        value = nil
                    } else if let parsed = Decimal(string: trimmed) {
                        value = parsed
                    }
                }
                .onAppear {
                    if let v = value {
                        text = NSDecimalNumber(decimal: v).stringValue
                    }
                }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(SikaTheme.Color.card)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(SikaTheme.Color.border, lineWidth: 1)
        )
    }
}
