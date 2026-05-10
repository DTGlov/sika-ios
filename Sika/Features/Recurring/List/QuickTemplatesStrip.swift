import SwiftUI

/// Horizontal strip of 5 hardcoded quick-template chips.
/// Tapping a chip pre-fills the Add sheet with the template's defaults.
struct QuickTemplatesStrip: View {
    let onTemplateTap: (QuickTemplate) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("QUICK EXPENSE TEMPLATES")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.5)
                .foregroundStyle(SikaTheme.Color.mutedForeground)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(QuickTemplates.all) { template in
                        chip(template)
                    }
                }
            }

            footerLink
        }
    }

    private func chip(_ template: QuickTemplate) -> some View {
        Button {
            onTemplateTap(template)
        } label: {
            HStack(spacing: 6) {
                Text(template.emoji)
                    .font(.system(size: 14))
                Text(template.label)
                    .font(SikaTheme.Typography.sans(12, weight: .semibold))
                    .foregroundStyle(SikaTheme.Color.foreground)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(SikaTheme.Color.card)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(SikaTheme.Color.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var footerLink: some View {
        Text(footerAttributed)
            .font(SikaTheme.Typography.sans(12))
            .foregroundStyle(SikaTheme.Color.mutedForeground)
    }

    /// "For income, manage your sources in Settings → Income."
    /// The "Settings → Income" portion is gold; tapping it could route to
    /// Settings (no-op for this PR — Settings rebuild ships later).
    private var footerAttributed: AttributedString {
        var s = AttributedString("For income, manage your sources in ")
        var link = AttributedString("Settings → Income")
        link.foregroundColor = SikaTheme.Color.sikaAccent
        link.font = SikaTheme.Typography.sans(12, weight: .semibold)
        s.append(link)
        s.append(AttributedString("."))
        return s
    }
}
