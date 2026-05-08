import SwiftUI

/// Income reminder card — appears when an income source's expected_day matches today.
/// Three actions: "Yes, log it" / "Not yet" / X.
/// All three suppress the card for the day; differ only in side effects.
struct IncomeNudgeCardView: View {
    let nudge: IncomeNudge
    let currencyCode: String
    let onLog: (IncomeNudge) -> Void
    let onSnooze: (IncomeNudge) -> Void
    let onDismiss: (IncomeNudge) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: SikaTheme.Spacing.md) {
            Text("💰")
                .font(.system(size: 24))

            VStack(alignment: .leading, spacing: 2) {
                Text("\(nudge.incomeSource.name) expected today")
                    .font(SikaTheme.Typography.sans(14, weight: .semibold))
                    .foregroundStyle(SikaTheme.Color.foreground)

                Text("Did you receive \(formatAmount(nudge.incomeSource.amount))?")
                    .font(SikaTheme.Typography.sans(12))
                    .foregroundStyle(SikaTheme.Color.mutedForeground)

                HStack(spacing: 8) {
                    Button(action: { onLog(nudge) }) {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14))
                            Text("Yes, log it")
                                .font(SikaTheme.Typography.sans(12, weight: .semibold))
                        }
                        .foregroundStyle(SikaTheme.Color.primaryForeground)
                        .padding(.horizontal, 12)
                        .frame(height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(SikaTheme.Color.sikaAccent)
                        )
                    }
                    .buttonStyle(.plain)

                    Button(action: { onSnooze(nudge) }) {
                        HStack(spacing: 6) {
                            Image(systemName: "clock")
                                .font(.system(size: 14))
                            Text("Not yet")
                                .font(SikaTheme.Typography.sans(12, weight: .medium))
                        }
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

            Button(action: { onDismiss(nudge) }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(SikaTheme.Color.mutedForeground.opacity(0.7))
                    .padding(.top, 2)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss income reminder")
        }
        .padding(SikaTheme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(SikaTheme.Color.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            SikaTheme.Color.sikaAccent.opacity(0.3),
                            lineWidth: 1
                        )
                )
        )
    }

    private func formatAmount(_ amount: Decimal) -> String {
        CurrencyFormatter.compact(amount, code: currencyCode)
    }
}
