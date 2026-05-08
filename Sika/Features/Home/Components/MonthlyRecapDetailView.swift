import SwiftUI

/// Detail view for a MonthlyRecap. Shows 5–7 stagger-animated cards.
/// Cards with `type == .headline` render large + centered.
/// Other cards render with leading icon + bold base headline + body.
/// Share button at bottom uses iOS native ShareLink.
///
/// Visual spec mirrors web's MonthlyRecap component
/// (src/components/monthly/monthly-recap.tsx):
/// - Stagger: opacity 0→1, y 20→0, duration 0.35s easeOut, delay = index × 0.08s
/// - Headline card: centered icon, 2xl bold accent-colored headline, optional stat pill
/// - Other cards: left icon (rounded 12pt 32×32), bold base headline, body, inline stat
/// - Share text matches web's exactly: "My month in money 🔥 — tracked with Sika"
struct MonthlyRecapDetailView: View {
    let recap: MonthlyRecap
    let onAppear: () -> Void
    let onShare: () -> Void

    @State private var hasMarkedViewed = false

    private static let inputFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        return f
    }()

    /// Web uses 'en-GB' (day-first). Match for parity ("27 Apr — 26 May").
    private static let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        f.locale = Locale(identifier: "en_GB")
        return f
    }()

    var body: some View {
        ScrollView {
            VStack(spacing: SikaTheme.Spacing.md) {
                monthRangeHeader

                ForEach(Array(recap.recapData.enumerated()), id: \.element.id) { index, card in
                    MonthlyCardItem(card: card, index: index)
                }

                shareButton
                    .padding(.top, SikaTheme.Spacing.md)
            }
            .padding(.horizontal, SikaTheme.Spacing.lg)
            .padding(.vertical, SikaTheme.Spacing.lg)
        }
        .navigationTitle("Monthly Recap")
        .navigationBarTitleDisplayMode(.inline)
        .background(SikaTheme.Color.background)
        .onAppear {
            if !hasMarkedViewed {
                hasMarkedViewed = true
                onAppear()
            }
        }
    }

    private var monthRangeHeader: some View {
        Text(formatMonthRange())
            .font(SikaTheme.Typography.sans(12))
            .foregroundStyle(SikaTheme.Color.mutedForeground)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.bottom, SikaTheme.Spacing.xs)
    }

    /// Share button matches web's chrome (card-bordered, muted, gold on tap-feedback).
    /// Uses iOS native ShareLink with text-only payload — matches web's
    /// `text: "My month in money 🔥 — tracked with Sika"` exactly.
    private var shareButton: some View {
        ShareLink(
            item: "My month in money 🔥 — tracked with Sika",
            subject: Text("My Sika Month")
        ) {
            HStack(spacing: SikaTheme.Spacing.sm) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 14, weight: .semibold))
                Text("Share my month")
                    .font(SikaTheme.Typography.sans(14, weight: .medium))
            }
            .foregroundStyle(SikaTheme.Color.mutedForeground)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(SikaTheme.Color.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(SikaTheme.Color.border, lineWidth: 1)
                    )
            )
        }
        // ShareLink doesn't expose a success callback. Mark shared on tap —
        // matches web's "fire shared_at after user taps" approximation.
        .simultaneousGesture(TapGesture().onEnded { onShare() })
    }

    private func formatMonthRange() -> String {
        guard let s = Self.inputFormatter.date(from: recap.monthStart),
              let e = Self.inputFormatter.date(from: recap.monthEnd) else {
            return ""
        }
        return "\(Self.displayFormatter.string(from: s)) — \(Self.displayFormatter.string(from: e))"
    }
}

// MARK: - MonthlyCardItem

private struct MonthlyCardItem: View {
    let card: MonthlyCard
    let index: Int

    @State private var hasAppeared = false

    private var accent: MonthlyAccent { card.accentColor ?? .neutral }

    private var accentColor: Color {
        switch accent {
        case .green:   return Color(hex: 0xD4A017)  // gold (web's "green" maps to gold)
        case .amber:   return Color(hex: 0xFBBF24)
        case .red:     return Color(hex: 0xF43F5E)
        case .blue:    return Color(hex: 0x60A5FA)
        case .neutral: return SikaTheme.Color.foreground
        }
    }

    private var bgFill: Color {
        switch accent {
        case .neutral: return SikaTheme.Color.muted
        default:       return accentColor.opacity(0.10)
        }
    }

    private var borderColor: Color {
        switch accent {
        case .neutral: return SikaTheme.Color.border
        default:       return accentColor.opacity(0.20)
        }
    }

    var body: some View {
        Group {
            if card.type == .headline {
                headlineLayout
            } else {
                standardLayout
            }
        }
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared ? 0 : 20)
        .onAppear {
            let delay = Double(index) * 0.08
            withAnimation(.easeOut(duration: 0.35).delay(delay)) {
                hasAppeared = true
            }
        }
    }

    private var headlineLayout: some View {
        VStack(spacing: SikaTheme.Spacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(bgFill)
                    .frame(width: 40, height: 40)
                Image(systemName: MonthlyCardSymbol.resolve(card.icon))
                    .font(.system(size: 18))
                    .foregroundStyle(accentColor)
            }

            Text(card.headline)
                .font(SikaTheme.Typography.sans(24, weight: .bold))
                .foregroundStyle(accentColor)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            Text(card.body)
                .font(SikaTheme.Typography.sans(14))
                .foregroundStyle(SikaTheme.Color.mutedForeground)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            if let stat = card.stat {
                HStack(spacing: SikaTheme.Spacing.sm) {
                    Text(stat.label)
                        .font(SikaTheme.Typography.sans(12))
                        .foregroundStyle(SikaTheme.Color.mutedForeground)
                    Text(stat.value)
                        .font(SikaTheme.Typography.sans(14, weight: .bold))
                        .foregroundStyle(accentColor)
                        .monospacedDigit()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(SikaTheme.Color.card)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(SikaTheme.Color.border, lineWidth: 1)
                        )
                )
                .padding(.top, 4)
            }
        }
        .padding(SikaTheme.Spacing.lg)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(bgFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(borderColor, lineWidth: 1)
                )
        )
    }

    private var standardLayout: some View {
        VStack(alignment: .leading, spacing: SikaTheme.Spacing.sm) {
            HStack(alignment: .top, spacing: SikaTheme.Spacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(bgFill)
                        .frame(width: 32, height: 32)
                    Image(systemName: MonthlyCardSymbol.resolve(card.icon))
                        .font(.system(size: 14))
                        .foregroundStyle(accentColor)
                }

                Text(card.headline)
                    .font(SikaTheme.Typography.sans(16, weight: .bold))
                    .foregroundStyle(accentColor)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Text(card.body)
                .font(SikaTheme.Typography.sans(14))
                .foregroundStyle(SikaTheme.Color.mutedForeground)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            if let stat = card.stat {
                HStack(spacing: 6) {
                    Text(stat.label)
                        .font(SikaTheme.Typography.sans(12))
                        .foregroundStyle(SikaTheme.Color.mutedForeground)
                    Text(stat.value)
                        .font(SikaTheme.Typography.sans(14, weight: .bold))
                        .foregroundStyle(accentColor)
                        .monospacedDigit()
                }
                .padding(.top, 2)
            }
        }
        .padding(SikaTheme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(bgFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(borderColor, lineWidth: 1)
                )
        )
    }
}
