import SwiftUI

/// "Should I buy it?" entry button for Home.
/// Tapping presents the DecisionSheet as a bottom sheet.
/// Mirror of src/components/decision/should-i-buy-button.tsx.
struct ShouldIBuyButton: View {
    /// Closure invoked after a successful "I bought it" outcome.
    /// Caller is expected to switch the main tab to Transactions.
    let onSwitchToTransactions: () -> Void

    @State private var sheetOpen = false

    var body: some View {
        Button {
            sheetOpen = true
        } label: {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(SikaTheme.Color.sikaAccent.opacity(0.10))
                        .frame(width: 36, height: 36)
                    Image(systemName: "bag")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(SikaTheme.Color.sikaAccent)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Should I buy it?")
                        .font(SikaTheme.Typography.sans(14, weight: .semibold))
                        .foregroundStyle(SikaTheme.Color.foreground)
                    Text("Got a purchase in mind? Sika tells you if it's the right time to buy it")
                        .font(SikaTheme.Typography.sans(12))
                        .foregroundStyle(SikaTheme.Color.mutedForeground)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(SikaTheme.Color.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                SikaTheme.Color.mutedForeground.opacity(0.2),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $sheetOpen) {
            DecisionSheet(onBought: onSwitchToTransactions)
        }
    }
}
