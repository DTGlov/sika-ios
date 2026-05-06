import SwiftUI

struct AddTransactionSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: SikaTheme.Spacing.lg) {
            Spacer()
            Image(systemName: "plus.circle")
                .font(.system(size: 48))
                .foregroundStyle(SikaTheme.Color.sikaAccent)
            Text("Add Transaction")
                .font(SikaTheme.Typography.sans(20, weight: .bold))
                .foregroundStyle(SikaTheme.Color.foreground)
            Text("Coming in 1B-2")
                .font(SikaTheme.Typography.sans(14))
                .foregroundStyle(SikaTheme.Color.mutedForeground)
            Spacer()
            Button("Close") { dismiss() }
                .foregroundStyle(SikaTheme.Color.mutedForeground)
                .padding(.bottom, SikaTheme.Spacing.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SikaTheme.Color.background)
    }
}
