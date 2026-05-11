import SwiftUI

/// Per-factor card for the /health detail page.
/// Shows: name + weight%, score, animated progress bar, and an
/// expandable section that surfaces the calculator-provided
/// `description` ("what this means") and `tip` ("to improve").
///
/// Reuses `HealthFactor.description` + `tip` directly — those fields
/// are computed contextually by `HealthScoreCalculator` (e.g.
/// "Your Life Savings covers 2.4 months of Needs." +
/// "Build Life Savings to cover 3 months (~GHS 12,000)"). Static
/// extension copy would diverge from the live data.
struct FactorCardView: View {
    let factor: HealthFactor
    let isVisible: Bool

    @State private var animatedProgress: Double = 0
    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerRow
            progressBar
            if isExpanded {
                expandedContent
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            expandButton
        }
        .padding(16)
        .background(SikaTheme.Color.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(SikaTheme.Color.mutedForeground.opacity(0.15), lineWidth: 1)
        )
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 12)
        .onAppear {
            if isVisible { triggerProgressAnimation() }
        }
        .onChange(of: isVisible) { _, newValue in
            if newValue { triggerProgressAnimation() }
        }
    }

    // MARK: - Subviews

    private var headerRow: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(factor.name)
                    .font(SikaTheme.Typography.sans(14, weight: .semibold))
                    .foregroundStyle(SikaTheme.Color.foreground)
                Text("Weight: \(factor.weight)%")
                    .font(SikaTheme.Typography.sans(11))
                    .foregroundStyle(SikaTheme.Color.mutedForeground)
            }
            Spacer()
            Text("\(factor.score)")
                .font(SikaTheme.Typography.sans(20, weight: .bold))
                .foregroundStyle(factorColor)
                .monospacedDigit()
        }
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(SikaTheme.Color.muted.opacity(0.4))
                    .frame(height: 8)
                RoundedRectangle(cornerRadius: 4)
                    .fill(factorColor)
                    .frame(
                        width: max(0, geo.size.width * animatedProgress),
                        height: 8
                    )
            }
        }
        .frame(height: 8)
    }

    @ViewBuilder
    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            section(label: "WHAT THIS MEANS", body: factor.description)
            if let tip = factor.tip, !tip.isEmpty {
                section(label: "TO IMPROVE", body: tip)
            }
        }
        .padding(.top, 4)
    }

    private func section(label: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(SikaTheme.Color.mutedForeground)
            Text(body)
                .font(SikaTheme.Typography.sans(12))
                .foregroundStyle(SikaTheme.Color.foreground)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var expandButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 4) {
                Text(isExpanded ? "Show less" : "Learn more")
                    .font(SikaTheme.Typography.sans(11, weight: .medium))
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(SikaTheme.Color.mutedForeground)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Color thresholds (audit Section: factor color band)

    private var factorColor: Color {
        switch factor.score {
        case 70...:   return Color(hex: 0x00D9A3)   // green — healthy
        case 40..<70: return Color(hex: 0xFBBF24)   // yellow — fair
        default:      return Color(hex: 0xF43F5E)   // red — needs attention
        }
    }

    private func triggerProgressAnimation() {
        withAnimation(.easeOut(duration: 0.8).delay(0.15)) {
            animatedProgress = Double(factor.score) / 100.0
        }
    }
}
