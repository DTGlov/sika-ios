import SwiftUI

/// Pending recurring transaction card — appears when an auto_log=false
/// recurring rule has missed occurrences.
/// Two actions: "Log it" / "Skip". No corner X (matches web's design).
///
/// Display name fallback: `recurring.note` then "Recurring". Full audit-spec
/// fallback (note → category.name → "Recurring") deferred until category-name
/// resolution is wired through the call site.
struct PendingRecurringCardView: View {
    let pending: PendingRecurring
    let currencyCode: String
    let onConfirm: (PendingRecurring) -> Void
    let onSkip: (PendingRecurring) -> Void

    private var displayName: String {
        if let note = pending.recurring.note, !note.isEmpty { return note }
        return "Recurring"
    }

    var body: some View {
        HStack(alignment: .top, spacing: SikaTheme.Spacing.md) {
            Text("🔄")
                .font(.system(size: 24))

            VStack(alignment: .leading, spacing: 2) {
                Text("\(displayName) due")
                    .font(SikaTheme.Typography.sans(14, weight: .semibold))
                    .foregroundStyle(SikaTheme.Color.foreground)

                Text("\(formatAmount(pending.recurring.amount)) · \(pending.latestDueDate ?? "")")
                    .font(SikaTheme.Typography.sans(12))
                    .foregroundStyle(SikaTheme.Color.mutedForeground)

                HStack(spacing: 8) {
                    Button(action: { onConfirm(pending) }) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14))
                            Text("Log it")
                                .font(SikaTheme.Typography.sans(12, weight: .semibold))
                        }
                        .foregroundStyle(SikaTheme.Color.primaryForeground)
                        .padding(.horizontal, 12)
                        .frame(height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(SikaTheme.Color.sikaWarning)  // amber #FBBF24
                        )
                    }
                    .buttonStyle(.plain)

                    Button(action: { onSkip(pending) }) {
                        Text("Skip")
                            .font(SikaTheme.Typography.sans(12, weight: .medium))
                            .foregroundStyle(SikaTheme.Color.mutedForeground)
                            .padding(.horizontal, 12)
                            .frame(height: 32)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(SikaTheme.Color.muted)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 8)
            }

            Spacer(minLength: 0)
        }
        .padding(SikaTheme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(SikaTheme.Color.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            SikaTheme.Color.sikaWarning.opacity(0.3),
                            lineWidth: 1
                        )
                )
        )
    }

    private func formatAmount(_ amount: Decimal) -> String {
        CurrencyFormatter.compact(amount, code: currencyCode)
    }
}
