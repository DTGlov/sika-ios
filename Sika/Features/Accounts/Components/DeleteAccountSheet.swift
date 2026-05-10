import SwiftUI

/// Two-step delete flow for accounts that have transactions referencing them.
/// Step 1: pick a reassign target (other active accounts).
/// Step 2: confirmation alert with explicit count + target name.
///
/// For accounts with zero transactions, the parent should bypass this sheet
/// and use a plain confirmation Alert instead.
struct DeleteAccountSheet: View {
    let account: Account
    let transactionCount: Int
    let candidates: [Account]
    let onDeleted: () async -> Void

    @Environment(AppState.self) private var appState
    @Environment(ToastManager.self) private var toasts
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTargetId: UUID? = nil
    @State private var showConfirmAlert: Bool = false
    @State private var isDeleting: Bool = false

    private var redColor: Color { Color(hex: 0xF43F5E) }

    private var selectedTarget: Account? {
        guard let id = selectedTargetId else { return nil }
        return candidates.first(where: { $0.id == id })
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                header
                Divider()
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(candidates) { acc in
                            row(acc)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                Spacer(minLength: 0)
                deleteButton
            }
            .background(SikaTheme.Color.background)
            .navigationTitle("Delete \(account.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Delete \(account.name)?", isPresented: $showConfirmAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    Task { await commitDelete() }
                }
            } message: {
                if let target = selectedTarget {
                    Text("Its \(transactionCount) transaction\(transactionCount == 1 ? "" : "s") will be moved to \(target.name). This can't be undone.")
                } else {
                    Text("This can't be undone.")
                }
            }
        }
        .presentationDetents([.large])
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("This account has \(transactionCount) transaction\(transactionCount == 1 ? "" : "s")")
                .font(SikaTheme.Typography.sans(14, weight: .semibold))
                .foregroundStyle(SikaTheme.Color.foreground)
            Text("Reassign them to which account?")
                .font(SikaTheme.Typography.sans(12))
                .foregroundStyle(SikaTheme.Color.mutedForeground)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func row(_ acc: Account) -> some View {
        let cfg = AccountTypeConfigs.config(for: acc.accountType)
        let isSelected = selectedTargetId == acc.id
        return Button {
            selectedTargetId = acc.id
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(cfg.color.opacity(0.094))
                        .frame(width: 36, height: 36)
                    Text(cfg.emoji)
                        .font(.system(size: 18))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(acc.name)
                        .font(SikaTheme.Typography.sans(14, weight: .semibold))
                        .foregroundStyle(SikaTheme.Color.foreground)
                    Text(cfg.label)
                        .font(SikaTheme.Typography.sans(11))
                        .foregroundStyle(SikaTheme.Color.mutedForeground)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(cfg.color)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isSelected ? cfg.color.opacity(0.06) : SikaTheme.Color.card)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? cfg.color : SikaTheme.Color.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var deleteButton: some View {
        Button {
            showConfirmAlert = true
        } label: {
            HStack(spacing: 6) {
                if isDeleting { ProgressView().scaleEffect(0.85).tint(redColor) }
                Image(systemName: "trash")
                Text(isDeleting ? "Deleting…" : "Delete account")
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
        .disabled(selectedTargetId == nil || isDeleting)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func commitDelete() async {
        guard let targetId = selectedTargetId else { return }
        isDeleting = true
        defer { isDeleting = false }

        let ok = await appState.deleteAccountWithReassign(account.id, reassignTo: targetId)
        if ok {
            toasts.show("Account deleted", kind: .success)
            await onDeleted()
            dismiss()
        } else {
            toasts.show("Failed to delete account", kind: .error)
        }
    }
}
