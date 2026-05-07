import SwiftUI

/// Step 2 content for expense or income transactions: emoji-icon category grid.
struct Step2CategoryGridView: View {
    @Bindable var viewModel: AddTransactionWizardViewModel
    let categories: [TransactionCategory]

    private var displayedCategories: [TransactionCategory] {
        viewModel.availableCategories(categories)
    }

    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: SikaTheme.Spacing.sm),
        GridItem(.flexible(), spacing: SikaTheme.Spacing.sm),
        GridItem(.flexible(), spacing: SikaTheme.Spacing.sm)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: SikaTheme.Spacing.lg) {
            Text("What for?")
                .font(SikaTheme.Typography.sans(28, weight: .bold))
                .foregroundStyle(SikaTheme.Color.foreground)
                .padding(.horizontal, SikaTheme.Spacing.lg)

            ScrollView {
                LazyVGrid(columns: columns, spacing: SikaTheme.Spacing.sm) {
                    ForEach(displayedCategories) { category in
                        CategoryCard(
                            category: category,
                            isSelected: viewModel.selectedCategoryId == category.id,
                            onTap: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                                    viewModel.selectedCategoryId = category.id
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, SikaTheme.Spacing.lg)
                .padding(.top, SikaTheme.Spacing.sm)
                .padding(.bottom, SikaTheme.Spacing.lg)
            }
            .scrollIndicators(.hidden)
        }
    }
}

/// Individual category card. Cream-muted background; gold border + tint when selected.
/// Web seeds emoji-prefixed names ("🍕 Eating Out"); we extract the prefix and display
/// the emoji centered above the trimmed label.
private struct CategoryCard: View {
    let category: TransactionCategory
    let isSelected: Bool
    let onTap: () -> Void

    private var emoji: String {
        let trimmed = category.name.trimmingCharacters(in: .whitespaces)
        var collected = ""
        for char in trimmed {
            if char.unicodeScalars.contains(where: { $0.properties.isEmojiPresentation || $0.value > 0x2600 }) {
                collected.append(char)
            } else {
                break
            }
        }
        return collected.isEmpty ? "📋" : collected
    }

    private var displayLabel: String {
        let trimmed = category.name.trimmingCharacters(in: .whitespaces)
        let withoutEmoji = trimmed.drop(while: { c in
            c.unicodeScalars.contains { $0.properties.isEmojiPresentation || $0.value > 0x2600 } || c.isWhitespace
        })
        let result = String(withoutEmoji)
        return result.isEmpty ? trimmed : result
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: SikaTheme.Spacing.sm) {
                Text(emoji)
                    .font(.system(size: 32))
                Text(displayLabel)
                    .font(SikaTheme.Typography.sans(13, weight: .semibold))
                    .foregroundStyle(SikaTheme.Color.foreground)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 100)
            .padding(.vertical, SikaTheme.Spacing.md)
            .background(
                isSelected
                    ? SikaTheme.Color.sikaAccent.opacity(0.15)
                    : SikaTheme.Color.muted
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(
                        isSelected ? SikaTheme.Color.sikaAccent : Color.clear,
                        lineWidth: 1.5
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }
}
