import SwiftUI

/// Account row in the Accounts tab list.
/// Per audit Section 3.1: dot + emoji tile + name + Default pill + type label
/// + action row (⚖️ + ✏️ + 🗑️). Trash hidden when isDefault. NO whole-card tap target.
struct AccountRowView: View {
    let account: Account
    let balance: Decimal
    let currencyCode: String
    let onReconcile: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var cfg: AccountTypeConfig {
        AccountTypeConfigs.config(for: account.accountType)
    }

    var body: some View {
        VStack(spacing: 0) {
            topRow
            Divider()
            balanceRow
        }
        .background(SikaTheme.Color.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(SikaTheme.Color.border, lineWidth: 1)
        )
    }

    private var topRow: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(cfg.color)
                .frame(width: 8, height: 8)

            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(cfg.color.opacity(0.094))
                    .frame(width: 40, height: 40)
                Text(cfg.emoji)
                    .font(.system(size: 20))
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(account.name)
                        .font(SikaTheme.Typography.sans(15, weight: .semibold))
                        .foregroundStyle(SikaTheme.Color.foreground)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    if account.isDefault == true {
                        defaultPill
                    }
                }
                Text(cfg.label)
                    .font(SikaTheme.Typography.sans(11))
                    .foregroundStyle(SikaTheme.Color.mutedForeground)
            }

            Spacer(minLength: 0)

            actionButtons
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var defaultPill: some View {
        HStack(spacing: 3) {
            Image(systemName: "star.fill")
                .font(.system(size: 9))
            Text("Default")
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundStyle(cfg.color)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(cfg.color.opacity(0.13))
        .clipShape(Capsule())
    }

    private var actionButtons: some View {
        HStack(spacing: 0) {
            iconButton(systemName: "scalemass", action: onReconcile)
                .accessibilityLabel("Reconcile")
            iconButton(systemName: "pencil", action: onEdit)
                .accessibilityLabel("Edit account")
            if account.isDefault != true {
                iconButton(systemName: "trash", action: onDelete)
                    .accessibilityLabel("Delete account")
            }
        }
    }

    private func iconButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14))
                .foregroundStyle(SikaTheme.Color.mutedForeground)
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var balanceRow: some View {
        HStack {
            Spacer()
            Text(CurrencyFormatter.format(balance, code: currencyCode))
                .font(SikaTheme.Typography.sans(17, weight: .bold))
                .foregroundStyle(cfg.color)
                .monospacedDigit()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}
