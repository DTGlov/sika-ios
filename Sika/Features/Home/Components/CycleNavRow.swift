import SwiftUI

/// Cycle navigation: ◀ / cycle.label / ▶ with "Past month" subtitle when not current.
struct CycleNavRow: View {
    let cycle: Cycle
    let isOnCurrentCycle: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Button(action: onPrevious) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(SikaTheme.Color.foreground)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)

                Spacer()

                Text(cycle.label)
                    .font(SikaTheme.Typography.sans(17, weight: .bold))
                    .foregroundStyle(SikaTheme.Color.foreground)

                Spacer()

                Button(action: onNext) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(isOnCurrentCycle
                            ? SikaTheme.Color.mutedForeground
                            : SikaTheme.Color.foreground)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .disabled(isOnCurrentCycle)
            }

            if !isOnCurrentCycle {
                Text("Past month")
                    .font(SikaTheme.Typography.sans(11))
                    .foregroundStyle(SikaTheme.Color.mutedForeground)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, SikaTheme.Spacing.lg)
        .animation(.easeOut(duration: 0.2), value: isOnCurrentCycle)
    }
}
