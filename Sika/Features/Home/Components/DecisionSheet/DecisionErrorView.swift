import SwiftUI

/// Error phase: simple message + retry button.
struct DecisionErrorView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32))
                .foregroundStyle(SikaTheme.Color.mutedForeground)

            Text(message)
                .font(SikaTheme.Typography.sans(14))
                .foregroundStyle(SikaTheme.Color.mutedForeground)
                .multilineTextAlignment(.center)

            Button(action: onRetry) {
                Text("Try again")
                    .font(SikaTheme.Typography.sans(14, weight: .semibold))
                    .foregroundStyle(SikaTheme.Color.primaryForeground)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(SikaTheme.Color.sikaAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, minHeight: 280)
    }
}
