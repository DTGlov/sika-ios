import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            switch appState.flow {
            case .signIn:
                SignInView()
            case .signUp:
                SignUpView()
            case .verifyEmail(let email):
                VerifyEmailView(email: email)
            case .authenticatingProfile:
                LoadingScreen()
            case .authenticated(let profile):
                AuthenticatedHomeView(profile: profile)
            }
        }
        .background(SikaTheme.Color.background)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: appState.flow)
    }
}

private struct LoadingScreen: View {
    var body: some View {
        VStack(spacing: SikaTheme.Spacing.md) {
            ProgressView().tint(SikaTheme.Color.sikaAccent)
            Text("Loading…")
                .font(SikaTheme.Typography.sans(14))
                .foregroundStyle(SikaTheme.Color.mutedForeground)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SikaTheme.Color.background)
    }
}
