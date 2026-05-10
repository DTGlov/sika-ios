import SwiftUI

/// Bordered destructive card with typed-DELETE confirmation.
/// On success: cascades 17 user-scoped tables + profiles + auth.users
/// via /api/profile/delete (Bearer auth).
struct DangerZoneSection: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var showDeleteAlert = false
    @State private var confirmText = ""
    @State private var isDeleting = false
    @State private var showFailureAlert = false

    private let redColor = Color(hex: 0xF43F5E)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Danger zone")
                    .font(SikaTheme.Typography.sans(15, weight: .semibold))
                    .foregroundStyle(redColor)
                Text("Permanently delete your account and all data. This cannot be undone.")
                    .font(SikaTheme.Typography.sans(11))
                    .foregroundStyle(SikaTheme.Color.mutedForeground)
            }

            Button {
                showDeleteAlert = true
            } label: {
                HStack(spacing: 6) {
                    if isDeleting {
                        ProgressView().scaleEffect(0.85).tint(redColor)
                    } else {
                        Image(systemName: "trash")
                    }
                    Text("Delete my account")
                }
                .font(SikaTheme.Typography.sans(13, weight: .semibold))
                .foregroundStyle(redColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(SikaTheme.Color.card)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(redColor.opacity(0.4), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(isDeleting)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(redColor.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(redColor.opacity(0.30), lineWidth: 1)
        )
        .alert("Delete your account?", isPresented: $showDeleteAlert) {
            TextField("DELETE", text: $confirmText)
                .autocorrectionDisabled(true)
            Button("Cancel", role: .cancel) {
                confirmText = ""
            }
            Button("Delete everything", role: .destructive) {
                Task { await handleDelete() }
            }
            .disabled(confirmText != "DELETE")
        } message: {
            Text("This will permanently erase all your transactions, accounts, goals, income sources, and settings. There is no undo. Type DELETE to confirm.")
        }
        .alert("Could not delete account", isPresented: $showFailureAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Email dtglover21@gmail.com for help.")
        }
    }

    private func handleDelete() async {
        isDeleting = true
        defer {
            isDeleting = false
            confirmText = ""
        }
        let ok = await appState.deleteAccount()
        if ok {
            dismiss()
        } else {
            showFailureAlert = true
        }
    }
}
