import SwiftUI

/// Empty-state sheet shown when the user taps the target picker but has no
/// targets yet. Reused in 1B-2c.1 when filtered results are empty.
struct EmptyTargetsSheet: View {
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: SikaTheme.Spacing.lg) {
            Spacer()

            Image(systemName: "target")
                .font(.system(size: 48))
                .foregroundStyle(SikaTheme.Color.sikaAccent)

            VStack(spacing: SikaTheme.Spacing.sm) {
                Text("No targets yet")
                    .font(SikaTheme.Typography.sans(20, weight: .bold))
                    .foregroundStyle(SikaTheme.Color.foreground)

                Text("Create a savings target in the Goals tab to use it here.")
                    .font(SikaTheme.Typography.sans(14))
                    .foregroundStyle(SikaTheme.Color.mutedForeground)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, SikaTheme.Spacing.xl)
            }

            Spacer()

            Button(action: { isPresented = false }) {
                Text("Got it")
                    .font(SikaTheme.Typography.sans(16, weight: .semibold))
                    .foregroundStyle(SikaTheme.Color.primaryForeground)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(Capsule().fill(SikaTheme.Color.sikaAccent))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, SikaTheme.Spacing.lg)
            .padding(.bottom, SikaTheme.Spacing.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SikaTheme.Color.background)
    }
}
