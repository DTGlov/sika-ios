import SwiftUI

/// Slate-gray "Reconcile an account balance instead" link below the number pad.
/// Tappable; parent decides what happens. T3 IBS-redesign wires this to set
/// `AppState.reconcileContext`, triggering the wizard's in-place reconcile
/// mode swap (no sheet dismiss/re-present) — mirrors the IBS "Reconcile
/// balance" remediation path.
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
