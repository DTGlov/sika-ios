import SwiftUI

/// 3-pill type selector: Expense / Income / Transfer.
/// Selected pill is gold; unselected pills are cream-muted.
struct TypePillSelector: View {
    @Binding var selected: TransactionType

    var body: some View {
        HStack(spacing: SikaTheme.Spacing.md) {
            ForEach(TransactionType.userCreatable) { type in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                        selected = type
                    }
                } label: {
                    Text(type.displayName)
                        .font(SikaTheme.Typography.sans(15, weight: .semibold))
                        .foregroundStyle(selected == type
                            ? SikaTheme.Color.primaryForeground
                            : SikaTheme.Color.foreground)
                        .padding(.horizontal, SikaTheme.Spacing.lg)
                        .padding(.vertical, SikaTheme.Spacing.sm)
                        .background(
                            Capsule()
                                .fill(selected == type
                                    ? SikaTheme.Color.sikaAccent
                                    : SikaTheme.Color.muted)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}
