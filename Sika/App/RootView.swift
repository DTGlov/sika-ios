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
                    .sheet(isPresented: shouldPresentOnboardingBinding) {
                        OnboardingSheet()
                    }
            }
        }
        .background(SikaTheme.Color.background)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: appState.flow)
    }

    private var shouldPresentOnboardingBinding: Binding<Bool> {
        Binding(
            get: { appState.shouldShowOnboarding },
            set: { newValue in
                if newValue == false {
                    appState.dismissOnboardingForSession()
                }
            }
        )
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
