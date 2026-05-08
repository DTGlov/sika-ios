import SwiftUI

/// AI-generated daily insight banner. Renders above CycleCard on Home.
///
/// Visual spec mirrors web's InsightStrip
/// (src/components/dashboard/insight-strip.tsx):
/// - card background
/// - 1pt accent-tinted border at 20% opacity
/// - Faint colored glow shadow at 6% opacity
/// - Padding: 16h × 12v
/// - Layout: leading SF Symbol (accent-tinted, 16pt) +
///           VStack(headline + body + optional stat) + trailing X
/// - Headline: 14pt semibold, foreground
/// - Body: 12pt muted
/// - Stat: 12pt accent-colored, semibold, monospaced numerals
struct DailyInsightBanner: View {
    let insight: DailyInsight
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: SikaTheme.Spacing.md) {
            iconView

            VStack(alignment: .leading, spacing: 2) {
                Text(insight.headline)
                    .font(SikaTheme.Typography.sans(14, weight: .semibold))
                    .foregroundStyle(SikaTheme.Color.foreground)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(insight.body)
                    .font(SikaTheme.Typography.sans(12))
                    .foregroundStyle(SikaTheme.Color.mutedForeground)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                if let stat = insight.stat {
                    HStack(spacing: 4) {
                        Text("\(stat.label):")
                        Text(stat.value)
                            .monospacedDigit()
                    }
                    .font(SikaTheme.Typography.sans(12, weight: .semibold))
                    .foregroundStyle(accentColor)
                    .padding(.top, 4)
                }
            }

            Spacer(minLength: 0)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(SikaTheme.Color.mutedForeground.opacity(0.7))
                    .padding(.top, 2)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss insight")
        }
        .padding(.horizontal, SikaTheme.Spacing.md)
        .padding(.vertical, SikaTheme.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(SikaTheme.Color.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(accentColor.opacity(0.2), lineWidth: 1)
                )
                .shadow(
                    color: accentColor.opacity(0.06),
                    radius: 20, x: 0, y: 0
                )
        )
    }

    private var iconView: some View {
        Image(systemName: InsightSymbol.resolve(insight.icon))
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(accentColor)
            .frame(width: 16, height: 16)
            .padding(.top, 2)
    }

    /// Maps the insight's accent enum to a SikaTheme color.
    /// `.green` reuses the gold accent because web's ACCENT_STYLES maps
    /// `green: { text: 'text-[#D4A017]' }` — green IS gold in this product.
    private var accentColor: Color {
        switch insight.accent {
        case .green:   return SikaTheme.Color.sikaAccent       // #D4A017
        case .amber:   return SikaTheme.Color.sikaWarning      // #FBBF24
        case .red:     return Color(hex: 0xF87171)             // lighter than .destructive
        case .blue:    return SikaTheme.Color.bucketSavings    // #60A5FA
        case .neutral: return SikaTheme.Color.mutedForeground
        }
    }
}
