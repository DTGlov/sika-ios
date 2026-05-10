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
                AuthenticatedRootView(profile: profile)
                    .sheet(isPresented: shouldPresentOnboardingBinding) {
                        OnboardingSheet()
                    }
                    .onAppear {
                        // Apply user's theme preference to the active UIWindow.
                        // Re-applied here (not just on toggle) so a fresh launch
                        // honors the persisted choice before any flash of the
                        // wrong scheme.
                        appState.applySystemTheme(profile.themePreferenceValue)
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
