import SwiftUI

struct AuthScreenContainer<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: () -> Content

    @State private var didAppear: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: SikaTheme.Spacing.xl) {
                header
                card
            }
            .padding(.horizontal, SikaTheme.Spacing.lg)
            .padding(.top, SikaTheme.Spacing.xl3)
            .padding(.bottom, SikaTheme.Spacing.xl)
            .frame(maxWidth: 360)
            .frame(maxWidth: .infinity)
        }
        .background(SikaTheme.Color.background)
        .scrollDismissesKeyboard(.interactively)
        .opacity(didAppear ? 1 : 0)
        .offset(y: didAppear ? 0 : 24)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) { didAppear = true }
        }
    }

    private var header: some View {
        VStack(spacing: SikaTheme.Spacing.md) {
            HStack(spacing: SikaTheme.Spacing.sm) {
                SikaMark(size: 36)
                Text("Sika")
                    .font(SikaTheme.Typography.sans(28, weight: .bold))
                    .foregroundStyle(SikaTheme.Color.foreground)
            }
            VStack(spacing: SikaTheme.Spacing.xs) {
                Text(title)
                    .font(SikaTheme.Typography.sans(22, weight: .semibold))
                    .foregroundStyle(SikaTheme.Color.foreground)
                Text(subtitle)
                    .font(SikaTheme.Typography.sans(14))
                    .foregroundStyle(SikaTheme.Color.mutedForeground)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: SikaTheme.Spacing.lg) {
            content()
        }
        .padding(SikaTheme.Spacing.xl)
        .background(SikaTheme.Color.card)
        .overlay(
            RoundedRectangle(cornerRadius: SikaTheme.Radius.xl2)
                .stroke(SikaTheme.Color.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: SikaTheme.Radius.xl2))
    }
}
