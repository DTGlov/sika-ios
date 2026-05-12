import SwiftUI

/// Slate-gray "Reconcile an account balance instead" link below the number pad.
/// Tappable; parent decides what happens. T3 wires this to dismiss the wizard
/// and open the standalone ReconcileAccountSheet pre-filled with the wizard's
/// currently-selected account.
struct ReconcileLink: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: SikaTheme.Spacing.xs) {
                // Image(systemName: "⚖️")
                //     .font(.system(size: 14))
                //     .foregroundStyle(SikaTheme.Color.mutedForeground)
                Text("⚖️").font(SikaTheme.Typography.sans(11))
                Text("Reconcile an account balance instead")
                    .font(SikaTheme.Typography.sans(13))
                    .foregroundStyle(SikaTheme.Color.mutedForeground)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, SikaTheme.Spacing.sm)
        }
        .buttonStyle(.plain)
    }
}
