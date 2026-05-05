import SwiftUI

struct SignInView: View {
    @Environment(AppState.self) private var appState

    @State private var email: String = ""
    @State private var password: String = ""
    @State private var emailError: String?
    @State private var passwordError: String?

    private var canSubmit: Bool {
        !email.isEmpty && !password.isEmpty && !appState.isPerformingAuthAction
    }

    var body: some View {
        AuthScreenContainer(title: "Welcome back", subtitle: "Sign in to your account") {
            SikaTextField(
                label: "Email",
                text: $email,
                kind: .email,
                placeholder: "you@example.com",
                error: emailError
            )

            SikaTextField(
                label: "Password",
                text: $password,
                kind: .password,
                placeholder: "Your password",
                error: passwordError
            )

            SikaPrimaryButton(
                title: "Sign in",
                isLoading: appState.isPerformingAuthAction,
                isEnabled: canSubmit,
                action: submit
            )

            if let serverError = appState.lastAuthError {
                Text(serverError)
                    .font(SikaTheme.Typography.sans(13))
                    .foregroundStyle(SikaTheme.Color.destructive)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }

            HStack(spacing: SikaTheme.Spacing.xs) {
                Text("Don't have an account?")
                    .font(SikaTheme.Typography.sans(14))
                    .foregroundStyle(SikaTheme.Color.mutedForeground)
                Button("Sign up") { appState.goToSignUp() }
                    .font(SikaTheme.Typography.sans(14, weight: .semibold))
                    .foregroundStyle(SikaTheme.Color.sikaAccent)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func submit() {
        emailError = AuthValidator.validateEmail(email)
        passwordError = AuthValidator.validatePassword(password)
        guard emailError == nil, passwordError == nil else { return }
        Task { await appState.signIn(email: email, password: password) }
    }
}
