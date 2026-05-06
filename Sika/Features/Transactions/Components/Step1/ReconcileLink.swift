import SwiftUI

/// Slate-gray "Reconcile an account balance instead" link below the number pad.
/// Tappable; parent decides what happens (in 1B-2a, shows a "Coming soon" toast).
struct ReconcileLink: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: SikaTheme.Spacing.xs) {
                Image(systemName: "scalemass")
                    .font(.system(size: 14))
                    .foregroundStyle(SikaTheme.Color.mutedForeground)
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
