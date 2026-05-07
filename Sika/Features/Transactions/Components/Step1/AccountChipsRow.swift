import SwiftUI

/// Wrap row of account chips with optional section label.
/// Selected chip has tinted outline + tinted text (defaults to bucketNeeds teal,
/// "active resource"). Unselected chips have cream-muted background, foreground
/// text, no border.
struct AccountChipsRow: View {
    let accounts: [Account]
    @Binding var selectedId: UUID?
    /// Color used for the chip's outline + text when selected.
    /// Defaults to bucketNeeds (teal) for Step 1; transfer's "To" picker uses sikaAccent (gold).
    var selectionTint: Color = SikaTheme.Color.bucketNeeds
    /// When false, the parent supplies its own section label ("From"/"To" in transfer).
    var showLabel: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: SikaTheme.Spacing.sm) {
            if showLabel {
                Text("Account")
                    .font(SikaTheme.Typography.sans(13))
                    .foregroundStyle(SikaTheme.Color.mutedForeground)
            }

            FlowLayout(spacing: SikaTheme.Spacing.sm) {
                ForEach(accounts) { account in
                    AccountChip(
                        account: account,
                        isSelected: selectedId == account.id,
                        selectionTint: selectionTint,
                        onTap: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                                selectedId = account.id
                            }
                        }
                    )
                }
            }
        }
    }
}

private struct AccountChip: View {
    let account: Account
    let isSelected: Bool
    let selectionTint: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: SikaTheme.Spacing.xs) {
                Text(emoji(for: account.accountType))
                    .font(.system(size: 14))
                Text(account.name)
                    .font(SikaTheme.Typography.sans(14, weight: .semibold))
                    .foregroundStyle(isSelected ? selectionTint : SikaTheme.Color.foreground)
            }
            .padding(.horizontal, SikaTheme.Spacing.md)
            .padding(.vertical, SikaTheme.Spacing.sm)
            .background(
                Capsule()
                    .fill(SikaTheme.Color.muted)
                    .overlay(
                        Capsule()
                            .strokeBorder(
                                isSelected ? selectionTint : Color.clear,
                                lineWidth: 1.5
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func emoji(for type: AccountType) -> String {
        switch type {
        case .general: return "🏦"
        case .wallet: return "👛"
        case .cash: return "💵"
        case .savings: return "🐷"
        case .investment: return "📈"
        case .other: return "📱"
        }
    }
}
