import SwiftUI

/// Wrap row of account chips with section label.
/// Selected chip has teal outline + teal text (bucketNeeds — "active resource").
/// Unselected chips have cream-muted background, foreground text, no border.
struct AccountChipsRow: View {
    let accounts: [Account]
    @Binding var selectedId: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: SikaTheme.Spacing.sm) {
            Text("Account")
                .font(SikaTheme.Typography.sans(13))
                .foregroundStyle(SikaTheme.Color.mutedForeground)

            FlowLayout(spacing: SikaTheme.Spacing.sm) {
                ForEach(accounts) { account in
                    AccountChip(
                        account: account,
                        isSelected: selectedId == account.id,
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
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: SikaTheme.Spacing.xs) {
                Text(emoji(for: account.accountType))
                    .font(.system(size: 14))
                Text(account.name)
                    .font(SikaTheme.Typography.sans(14, weight: .semibold))
                    .foregroundStyle(isSelected
                        ? SikaTheme.Color.bucketNeeds
                        : SikaTheme.Color.foreground)
            }
            .padding(.horizontal, SikaTheme.Spacing.md)
            .padding(.vertical, SikaTheme.Spacing.sm)
            .background(
                Capsule()
                    .fill(SikaTheme.Color.muted)
                    .overlay(
                        Capsule()
                            .strokeBorder(
                                isSelected ? SikaTheme.Color.bucketNeeds : Color.clear,
                                lineWidth: 1.5
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }

    /// Emoji for each account type. Fallback when accounts table doesn't have an
    /// emoji/icon column (refine when account creation UI ships).
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
