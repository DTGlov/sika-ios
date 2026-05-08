import SwiftUI

/// Result phase: verdict pill + math card + "Sika says" + 2 CTAs.
/// Mirror of decision-sheet.tsx result block.
struct DecisionResultView: View {
    let decision: DecisionData
    let onSkip: () -> Void
    let onBought: () -> Void

    private let goldColor = SikaTheme.Color.sikaAccent
    private let darkText  = SikaTheme.Color.primaryForeground
    private let roseColor = SikaTheme.Color.sikaDanger

    private struct AccentColors {
        let border: Color
        let background: Color
        let text: Color
        let iconName: String
    }

    private var accent: AccentColors {
        switch decision.accent {
        case .green:
            return AccentColors(
                border: Color(hex: 0x00D9A3),
                background: Color(hex: 0x00D9A3).opacity(0.094),
                text: Color(hex: 0x00D9A3),
                iconName: "checkmark.circle.fill"
            )
        case .amber:
            return AccentColors(
                border: Color(hex: 0xFBBF24),
                background: Color(hex: 0xFBBF24).opacity(0.094),
                text: Color(hex: 0xFBBF24),
                iconName: "questionmark.circle.fill"
            )
        case .red:
            return AccentColors(
                border: Color(hex: 0xF43F5E),
                background: Color(hex: 0xF43F5E).opacity(0.094),
                text: Color(hex: 0xF43F5E),
                iconName: "exclamationmark.triangle.fill"
            )
        case .blue:
            return AccentColors(
                border: Color(hex: 0x60A5FA),
                background: Color(hex: 0x60A5FA).opacity(0.094),
                text: Color(hex: 0x60A5FA),
                iconName: "chart.line.uptrend.xyaxis"
            )
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            verdictBanner
            theMathCard
            sikaSaysCard
            ctaRow
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private var verdictBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: accent.iconName)
                .font(.system(size: 20))
                .foregroundStyle(accent.text)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(decision.verdictLine)
                    .font(SikaTheme.Typography.sans(16, weight: .bold))
                    .foregroundStyle(SikaTheme.Color.foreground)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Text(decision.verdict.displayLabel)
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(accent.text)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(accent.background)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(accent.border.opacity(0.25), lineWidth: 1)
        )
    }

    private var theMathCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("THE MATH")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.5)
                .foregroundStyle(SikaTheme.Color.mutedForeground)

            HStack {
                Text("\(decision.impact.bucketAfter.bucket.displayLabel) after")
                    .font(SikaTheme.Typography.sans(14))
                    .foregroundStyle(SikaTheme.Color.mutedForeground)

                Spacer()

                HStack(spacing: 6) {
                    Text("\(decision.impact.bucketAfter.pctAfter)%")
                        .font(SikaTheme.Typography.sans(14, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(
                            decision.impact.bucketAfter.overBudget
                                ? roseColor
                                : SikaTheme.Color.foreground
                        )
                    if decision.impact.bucketAfter.overBudget {
                        Text("over budget")
                            .font(SikaTheme.Typography.sans(11))
                            .foregroundStyle(roseColor)
                    }
                }
            }

            if let goalImpact = decision.impact.goalImpact {
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top) {
                        Text(goalImpact.goalName)
                            .font(SikaTheme.Typography.sans(14))
                            .foregroundStyle(SikaTheme.Color.mutedForeground)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Spacer(minLength: 8)
                        Text("\(goalImpact.pctOfGoal)% of goal")
                            .font(SikaTheme.Typography.sans(14, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(SikaTheme.Color.foreground)
                    }
                    Text(goalImpact.comment)
                        .font(SikaTheme.Typography.sans(11))
                        .foregroundStyle(SikaTheme.Color.mutedForeground)
                }
            }

            if let oppCost = decision.impact.opportunityCost {
                Divider()
                HStack(alignment: .top, spacing: 4) {
                    Text("Alternatively:")
                        .font(SikaTheme.Typography.sans(11))
                        .foregroundStyle(SikaTheme.Color.mutedForeground)
                    Text(oppCost)
                        .font(SikaTheme.Typography.sans(11))
                        .foregroundStyle(SikaTheme.Color.mutedForeground)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SikaTheme.Color.muted)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var sikaSaysCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SIKA SAYS")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.5)
                .foregroundStyle(SikaTheme.Color.mutedForeground)

            Text(decision.reasoning)
                .font(SikaTheme.Typography.sans(14))
                .foregroundStyle(SikaTheme.Color.mutedForeground)
                .lineSpacing(4)
                .multilineTextAlignment(.leading)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SikaTheme.Color.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(SikaTheme.Color.mutedForeground.opacity(0.2), lineWidth: 1)
        )
    }

    private var ctaRow: some View {
        HStack(spacing: 8) {
            Button(action: onSkip) {
                Text("Nah, skip")
                    .font(SikaTheme.Typography.sans(14, weight: .semibold))
                    .foregroundStyle(SikaTheme.Color.mutedForeground)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(SikaTheme.Color.card)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                SikaTheme.Color.mutedForeground.opacity(0.2),
                                lineWidth: 1
                            )
                    )
            }
            .buttonStyle(.plain)

            Button(action: onBought) {
                Text("I bought it")
                    .font(SikaTheme.Typography.sans(14, weight: .semibold))
                    .foregroundStyle(darkText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(goldColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 4)
    }
}
