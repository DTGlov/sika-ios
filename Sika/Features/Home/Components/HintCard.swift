import SwiftUI

/// Reusable dismissible hint card. Generic — used by:
/// - Home: dashboard_card_intro, dashboard_buckets_intro
/// - (future) Accounts page, Recurring page, Settings, Goals page, etc.
///
/// Visual spec mirrors web's HintCard (src/components/hint-card.tsx):
/// - card background
/// - 1pt gold border at 30% opacity
/// - 16pt corners, 12pt internal padding
/// - Optional leading icon (gold), title, body, optional CTA button
/// - Trailing X dismiss button
/// - Skeleton placeholder while hintsLoaded is false (prevents flash)
/// - Slide+fade animation on enter/exit
///
/// The body text parameter is named `message` to avoid colliding with
/// SwiftUI's `body: some View` requirement.
struct HintCard: View {
    @Environment(AppState.self) private var appState

    let hintId: HintId
    let title: String
    let message: String
    let icon: Image?
    let cta: String?

    init(
        hintId: HintId,
        title: String,
        message: String,
        icon: Image? = nil,
        cta: String? = nil
    ) {
        self.hintId = hintId
        self.title = title
        self.message = message
        self.icon = icon
        self.cta = cta
    }

    var body: some View {
        if !appState.hintsLoaded {
            // Skeleton placeholder while we wait for the dismissed_hints fetch.
            // Same height as a typical 2-line hint to prevent layout shift.
            RoundedRectangle(cornerRadius: 16)
                .fill(SikaTheme.Color.card)
                .frame(height: 72)
        } else if appState.isDismissed(hintId) {
            EmptyView()
        } else {
            cardContent
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
        }
    }

    private var cardContent: some View {
        HStack(alignment: .top, spacing: SikaTheme.Spacing.md) {
            if let icon {
                icon
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
                    .foregroundStyle(SikaTheme.Color.sikaAccent)
                    .padding(.top, 2)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(SikaTheme.Typography.sans(14, weight: .semibold))
                    .foregroundStyle(SikaTheme.Color.foreground)

                Text(message)
                    .font(SikaTheme.Typography.sans(12))
                    .foregroundStyle(SikaTheme.Color.mutedForeground)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                if let cta {
                    Button(action: dismiss) {
                        Text(cta)
                            .font(SikaTheme.Typography.sans(12, weight: .semibold))
                            .foregroundStyle(SikaTheme.Color.primaryForeground)
                            .padding(.horizontal, 12)
                            .frame(height: 28)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(SikaTheme.Color.sikaAccent)
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                }
            }

            Spacer(minLength: 0)

            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(SikaTheme.Color.mutedForeground.opacity(0.7))
                    .padding(.top, 2)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss hint")
        }
        .padding(SikaTheme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(SikaTheme.Color.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            SikaTheme.Color.sikaAccent.opacity(0.3),
                            lineWidth: 1
                        )
                )
        )
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.2)) {
            Task { await appState.dismissHint(hintId) }
        }
    }
}
