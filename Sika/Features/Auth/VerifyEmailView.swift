import SwiftUI

struct VerifyEmailView: View {
    let email: String

    @Environment(AppState.self) private var appState
    @Environment(ToastManager.self) private var toasts

    @State private var iconAppeared: Bool = false
    @State private var resendCooldown: Int = 0
    @State private var isResending: Bool = false
    @State private var cooldownTask: Task<Void, Never>?

    private var canResend: Bool { resendCooldown == 0 && !isResending }

    var body: some View {
        AuthScreenContainer(title: "Check your email", subtitle: "We sent a verification link to \(email).") {
            mailIcon

            Text("Click the link in your inbox to activate your Sika account, then come back here to sign in.")
                .font(SikaTheme.Typography.sans(14))
                .foregroundStyle(SikaTheme.Color.mutedForeground)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            Button(action: resend) {
                Text(resendButtonTitle)
                    .font(SikaTheme.Typography.sans(14, weight: .semibold))
                    .foregroundStyle(canResend ? SikaTheme.Color.sikaAccent : SikaTheme.Color.mutedForeground)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .disabled(!canResend)

            HStack(spacing: SikaTheme.Spacing.xs) {
                Text("Wrong email?")
                    .font(SikaTheme.Typography.sans(14))
                    .foregroundStyle(SikaTheme.Color.mutedForeground)
                Button("Sign up again") { appState.goToSignUp() }
                    .font(SikaTheme.Typography.sans(14, weight: .semibold))
                    .foregroundStyle(SikaTheme.Color.sikaAccent)
            }
            .frame(maxWidth: .infinity)

            Text("Don't see it? Check your spam folder.")
                .font(SikaTheme.Typography.sans(12))
                .foregroundStyle(SikaTheme.Color.mutedForeground)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1)) {
                iconAppeared = true
            }
        }
        .onDisappear { cooldownTask?.cancel() }
    }

    private var mailIcon: some View {
        Image(systemName: "envelope.badge")
            .font(.system(size: 32, weight: .semibold))
            .foregroundStyle(SikaTheme.Color.sikaAccent)
            .frame(width: 64, height: 64)
            .background(SikaTheme.Color.sikaAccent.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: SikaTheme.Radius.xl))
            .scaleEffect(iconAppeared ? 1 : 0.6)
            .opacity(iconAppeared ? 1 : 0)
            .frame(maxWidth: .infinity)
    }

    private var resendButtonTitle: String {
        if isResending { return "Sending…" }
        if resendCooldown > 0 { return "Resend in \(resendCooldown)s" }
        return "Resend email"
    }

    private func resend() {
        isResending = true
        Task {
            do {
                try await appState.resendVerificationEmail(email: email)
                toasts.show("Verification email sent", kind: .success)
                startCooldown()
            } catch {
                toasts.show(error.localizedDescription, kind: .error)
            }
            isResending = false
        }
    }

    private func startCooldown() {
        cooldownTask?.cancel()
        resendCooldown = 60
        cooldownTask = Task {
            while resendCooldown > 0 {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                resendCooldown -= 1
            }
        }
    }
}
