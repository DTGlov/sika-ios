import SwiftUI

/// Modal sheet shown when a badge unlocks. Auto-dismisses after 5s.
/// Spring entrance on the medallion. Haptic on appear.
/// NO confetti — confetti is reserved for the tier-up celebration (Phase 9.5).
struct BadgeCelebrationSheet: View {
    let userBadge: UserBadge
    let onDismiss: () async -> Void

    @State private var hasAppeared = false
    @State private var dismissTimer: Task<Void, Never>?

    private var catalogEntry: BadgeCatalogEntry? {
        BadgeCatalog.entry(for: userBadge.badgeId)
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            if let entry = catalogEntry {
                medallion(entry: entry)

                Text("BADGE UNLOCKED")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(2.5)
                    .foregroundStyle(SikaTheme.Color.mutedForeground)
                    .padding(.top, 4)

                Text(entry.name)
                    .font(SikaTheme.Typography.sans(24, weight: .bold))
                    .foregroundStyle(entry.rarity.frameColor)

                Text(entry.description)
                    .font(SikaTheme.Typography.sans(14))
                    .foregroundStyle(SikaTheme.Color.mutedForeground)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)

                Button {
                    Task { await dismiss() }
                } label: {
                    Text("Continue")
                        .font(SikaTheme.Typography.sans(14, weight: .semibold))
                        .foregroundStyle(SikaTheme.Color.primaryForeground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(entry.rarity.frameColor)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
            } else {
                Text("Badge unlocked")
                    .font(SikaTheme.Typography.sans(18, weight: .bold))
                    .foregroundStyle(SikaTheme.Color.foreground)
                Button("Continue") { Task { await dismiss() } }
                    .buttonStyle(.plain)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SikaTheme.Color.background)
        .onAppear {
            triggerHapticAndStartTimer()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                hasAppeared = true
            }
        }
        .onDisappear {
            dismissTimer?.cancel()
        }
    }

    private func medallion(entry: BadgeCatalogEntry) -> some View {
        ZStack {
            Circle()
                .fill(entry.rarity.frameColor.opacity(0.20))
                .frame(width: 112, height: 112)
            Circle()
                .stroke(entry.rarity.frameColor, lineWidth: 3)
                .frame(width: 112, height: 112)
            Image(systemName: entry.iconName)
                .font(.system(size: 48))
                .foregroundStyle(entry.rarity.frameColor)
        }
        .scaleEffect(hasAppeared ? 1.0 : 0.5)
        .opacity(hasAppeared ? 1.0 : 0.0)
        .shadow(color: entry.rarity.frameColor.opacity(0.4), radius: 30)
    }

    private func triggerHapticAndStartTimer() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        dismissTimer = Task {
            try? await Task.sleep(for: .seconds(5))
            if !Task.isCancelled {
                await dismiss()
            }
        }
    }

    private func dismiss() async {
        dismissTimer?.cancel()
        await onDismiss()
    }
}
