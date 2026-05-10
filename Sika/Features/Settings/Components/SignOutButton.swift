import SwiftUI

/// Outline button, full-width, red text. NOT in danger zone — sits on its own.
/// Sign-out is reversible; no confirmation alert (matches web).
struct SignOutButton: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    private let redColor = Color(hex: 0xF43F5E)

    var body: some View {
        Button {
            Task {
                await appState.signOut()
                dismiss()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                Text("Sign out")
            }
            .font(SikaTheme.Typography.sans(15, weight: .semibold))
            .foregroundStyle(redColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(SikaTheme.Color.card)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(redColor.opacity(0.4), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(appState.isPerformingAuthAction)
    }
}
