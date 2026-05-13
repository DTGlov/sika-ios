import SwiftUI

/// Identifiable context populated by `validateBalance` and consumed by
/// `InsufficientBalanceOverlay`. Carries the failing account's id, name,
/// frozen balance, and the requested amount so the overlay's headline /
/// description / handlers can read everything from one struct.
struct InsufficientBalanceContext: Identifiable, Equatable {
    let id: UUID = UUID()
    let accountId: UUID
    let accountName: String
    let accountBalance: Decimal
    let amountRequested: Decimal
}

/// Web-aligned Insufficient Balance overlay. Rendered as `.overlay` on the
/// wizard's container — NOT a second `.sheet`. The main wizard sheet stays
/// mounted; the overlay slides up on top. Mirrors web's pattern of never
/// dismissing the main sheet during a remediation, which sidesteps the
/// ~350ms detent re-present quirk that previously affected the reconcile
/// hand-off path.
///
/// Three content variants keyed off balance value (underwater / empty /
/// insufficient) share the same three remediation rows: Top up / Use a
/// different account / Reconcile balance. No "Log anyway" override.
struct InsufficientBalanceOverlay: View {
    let context: InsufficientBalanceContext
    let currencyCode: String

    let onTopUp: () -> Void
    let onUseDifferentAccount: () -> Void
    let onReconcile: () -> Void
    let onCancel: () -> Void

    @State private var rowTapTrigger: UUID = UUID()
    @State private var handlerFireTrigger: UUID = UUID()

    private enum ContentVariant { case underwater, empty, insufficient }

    private var variant: ContentVariant {
        if context.accountBalance < 0 { return .underwater }
        if context.accountBalance == 0 { return .empty }
        return .insufficient
    }

    private var headline: String {
        switch variant {
        case .underwater:
            return "\(context.accountName) is underwater"
        case .empty:
            return "\(context.accountName) is empty"
        case .insufficient:
            let bal = CurrencyFormatter.format(context.accountBalance, code: currencyCode)
            return "\(context.accountName) only has \(bal)"
        }
    }

    private var description: String {
        switch variant {
        case .underwater:
            let bal = CurrencyFormatter.format(context.accountBalance, code: currencyCode)
            return "Balance is \(bal) — you're already overspent."
        case .empty:
            return "\(context.accountName) has no money to spend right now."
        case .insufficient:
            let req = CurrencyFormatter.format(context.amountRequested, code: currencyCode)
            let bal = CurrencyFormatter.format(context.accountBalance, code: currencyCode)
            return "You're trying to spend \(req), but only \(bal) is available."
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Scrim: ultraThinMaterial.opacity(0.6) per locked architectural
            // decision. Tap to dismiss.
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.6)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { onCancel() }

            VStack(spacing: 0) {
                header
                Divider().background(Color(hex: 0x27272A))
                contentBlock
                remediationRows
                cancelButton
            }
            .frame(maxWidth: 448)
            .frame(maxWidth: .infinity)
            .background(Color(hex: 0x141416))
            .clipShape(
                .rect(
                    topLeadingRadius: 24,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 24
                )
            )
            .overlay(alignment: .top) {
                UnevenRoundedRectangle(
                    topLeadingRadius: 24,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 24
                )
                .stroke(Color(hex: 0x27272A), lineWidth: 1)
            }
        }
        .sensoryFeedback(.selection, trigger: rowTapTrigger)
        .sensoryFeedback(.success, trigger: handlerFireTrigger)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: 0xFBBF24).opacity(0.1))
                    .frame(width: 40, height: 40)
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Color(hex: 0xFBBF24))
            }

            Spacer()

            Button {
                onCancel()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color(hex: 0x52525B))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }

    private var contentBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(headline)
                .font(SikaTheme.Typography.sans(20, weight: .bold))
                .foregroundStyle(SikaTheme.Color.foreground)

            Text(description)
                .font(SikaTheme.Typography.sans(14))
                .foregroundStyle(Color(hex: 0xA1A1AA))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private var remediationRows: some View {
        VStack(spacing: 8) {
            remediationRow(
                iconName: "plus",
                iconColor: Color(hex: 0xD4A017),
                primary: "Top up \(context.accountName)",
                secondary: "Log incoming money to this account"
            ) {
                rowTapTrigger = UUID()
                handlerFireTrigger = UUID()
                onTopUp()
            }

            remediationRow(
                iconName: "arrow.left.arrow.right",
                iconColor: Color(hex: 0x60A5FA),
                primary: "Use a different account",
                secondary: "Pick another account to spend from"
            ) {
                rowTapTrigger = UUID()
                handlerFireTrigger = UUID()
                onUseDifferentAccount()
            }

            remediationRow(
                iconName: "scale.3d",
                iconColor: Color(hex: 0xA78BFA),
                primary: "Reconcile balance",
                secondary: "If your real balance is actually higher"
            ) {
                rowTapTrigger = UUID()
                handlerFireTrigger = UUID()
                onReconcile()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func remediationRow(
        iconName: String,
        iconColor: Color,
        primary: String,
        secondary: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(iconColor.opacity(0.1))
                        .frame(width: 32, height: 32)
                    Image(systemName: iconName)
                        .font(.system(size: 16))
                        .foregroundStyle(iconColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(primary)
                        .font(SikaTheme.Typography.sans(14, weight: .medium))
                        .foregroundStyle(SikaTheme.Color.foreground)
                        .multilineTextAlignment(.leading)
                    Text(secondary)
                        .font(SikaTheme.Typography.sans(12))
                        .foregroundStyle(Color(hex: 0xA1A1AA))
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundStyle(Color(hex: 0x52525B))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: 0x1C1C1F))
            )
        }
        .buttonStyle(.plain)
    }

    private var cancelButton: some View {
        Button {
            onCancel()
        } label: {
            Text("Cancel")
                .font(SikaTheme.Typography.sans(14))
                .foregroundStyle(Color(hex: 0xA1A1AA))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        }
        .buttonStyle(.plain)
    }
}
