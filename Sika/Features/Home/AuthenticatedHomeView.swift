import SwiftUI

struct AuthenticatedHomeView: View {
    let profile: Profile

    @Environment(AppState.self) private var appState

    private var greeting: String {
        if let firstName = profile.firstName { return "Hi, \(firstName)!" }
        return "Hi!"
    }

    var body: some View {
        VStack(spacing: SikaTheme.Spacing.xl) {
            Spacer()

            SikaMark(size: 96)

            VStack(spacing: SikaTheme.Spacing.sm) {
                Text(greeting)
                    .font(SikaTheme.Typography.sans(24, weight: .bold))
                    .foregroundStyle(SikaTheme.Color.foreground)
                Text("Foundation ready")
                    .font(SikaTheme.Typography.sans(14))
                    .foregroundStyle(SikaTheme.Color.mutedForeground)
            }

            Spacer()

            SikaPrimaryButton(
                title: "Sign out",
                isLoading: appState.isPerformingAuthAction,
                isEnabled: !appState.isPerformingAuthAction
            ) {
                Task { await appState.signOut() }
            }
            .padding(.horizontal, SikaTheme.Spacing.lg)
            .padding(.bottom, SikaTheme.Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SikaTheme.Color.background)
    }
}
