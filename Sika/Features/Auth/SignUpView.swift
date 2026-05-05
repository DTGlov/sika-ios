import SwiftUI

struct SignUpView: View {
    @Environment(AppState.self) private var appState

    @State private var fullName: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var nameError: String?
    @State private var emailError: String?
    @State private var passwordError: String?

    private var canSubmit: Bool {
        !fullName.isEmpty && !email.isEmpty && !password.isEmpty && !appState.isPerformingAuthAction
    }

    var body: some View {
        AuthScreenContainer(title: "Create your account", subtitle: "Start tracking your money in seconds") {
            SikaTextField(
                label: "Full name",
                text: $fullName,
                kind: .name,
                placeholder: "Kofi Mensah",
                error: nameError
            )

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
                placeholder: "At least 6 characters",
                error: passwordError
            )

            SikaPrimaryButton(
                title: "Create account",
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

            VStack(spacing: SikaTheme.Spacing.xs) {
                HStack(spacing: 4) {
                    Text("By creating an account, you agree to our")
                        .font(SikaTheme.Typography.sans(12))
                        .foregroundStyle(SikaTheme.Color.mutedForeground)
                    Button("privacy policy") {
                        print("Privacy policy tap")
                    }
                    .font(SikaTheme.Typography.sans(12, weight: .semibold))
                    .foregroundStyle(SikaTheme.Color.sikaAccent)
                }
                Text(".")
                    .font(SikaTheme.Typography.sans(12))
                    .foregroundStyle(SikaTheme.Color.mutedForeground)
                    .hidden()
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: SikaTheme.Spacing.xs) {
                Text("Already have an account?")
                    .font(SikaTheme.Typography.sans(14))
                    .foregroundStyle(SikaTheme.Color.mutedForeground)
                Button("Sign in") { appState.goToSignIn() }
                    .font(SikaTheme.Typography.sans(14, weight: .semibold))
                    .foregroundStyle(SikaTheme.Color.sikaAccent)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func submit() {
        nameError = AuthValidator.validateName(fullName)
        emailError = AuthValidator.validateEmail(email)
        passwordError = AuthValidator.validatePassword(password)
        guard nameError == nil, emailError == nil, passwordError == nil else { return }
        Task {
            await appState.signUp(
                email: email.trimmingCharacters(in: .whitespaces),
                password: password,
                fullName: fullName.trimmingCharacters(in: .whitespaces)
            )
        }
    }
}
