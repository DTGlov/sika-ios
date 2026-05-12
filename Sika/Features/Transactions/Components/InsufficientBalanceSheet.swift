import SwiftUI

/// Context describing why IBS fires — captured from the wizard's
/// validateBalance() at save time. Identifiable so the sheet can be
/// presented via `.sheet(item:)`, which avoids the SwiftUI race where a
/// transient `isPresented` flag flips back to false before the sheet sees
/// the updated payload.
struct InsufficientBalanceContext: Identifiable, Equatable {
    let id: UUID = UUID()
    let accountId: UUID
    let accountName: String
    let currentBalance: Decimal
    let attemptedAmount: Decimal
}

/// Three-action sheet that surfaces when an expense or transfer-from would
/// take an account negative. Income never triggers IBS (no debit).
/// Paid-from-target overdrafts are a separate guard (Phase 9.5c).
struct InsufficientBalanceSheet: View {
    let accountName: String
    let currentBalance: Decimal
    let attemptedAmount: Decimal
    let currencyCode: String

    let onCancel: () -> Void
    let onReconcile: () -> Void
    let onLogAnyway: () -> Void

    @Environment(\.dismiss) private var dismiss

    private let amberColor = Color(hex: 0xFBBF24)
    private let darkText = Color(hex: 0x0E1A2E)

    private var deficit: Decimal {
        attemptedAmount - currentBalance
    }

    var body: some View {
        VStack(spacing: 20) {
            // Icon + title
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(amberColor)

                Text("Insufficient balance")
                    .font(SikaTheme.Typography.sans(18, weight: .semibold))
                    .foregroundStyle(SikaTheme.Color.foreground)
            }
            .padding(.top, 24)

            // Body copy
            VStack(spacing: 6) {
                Text("\(accountName) has \(CurrencyFormatter.format(currentBalance, code: currencyCode)).")
                    .font(SikaTheme.Typography.sans(14))
                    .foregroundStyle(SikaTheme.Color.foreground)
                    .multilineTextAlignment(.center)

                Text("This transaction would put it \(CurrencyFormatter.format(deficit, code: currencyCode)) in the red.")
                    .font(SikaTheme.Typography.sans(13))
                    .foregroundStyle(SikaTheme.Color.mutedForeground)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 24)

            Spacer(minLength: 0)

            // Three actions
            VStack(spacing: 10) {
                Button {
                    onReconcile()
                    dismiss()
                } label: {
                    Text("Reconcile this account")
                        .font(SikaTheme.Typography.sans(15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(SikaTheme.Color.card)
                        .foregroundStyle(SikaTheme.Color.foreground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(SikaTheme.Color.border, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)

                Button {
                    onLogAnyway()
                    dismiss()
                } label: {
                    Text("Log anyway")
                        .font(SikaTheme.Typography.sans(15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(amberColor.opacity(0.18))
                        .foregroundStyle(amberColor)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                Button {
                    onCancel()
                    dismiss()
                } label: {
                    Text("Cancel")
                        .font(SikaTheme.Typography.sans(15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundStyle(SikaTheme.Color.mutedForeground)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SikaTheme.Color.background)
        .presentationDetents([.medium])
    }
}
