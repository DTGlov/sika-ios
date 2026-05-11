import SwiftUI

/// Logging streak stat card. Top→bottom: icon tile + eyebrow / big
/// number + unit / divider / three detail rows (Longest, Last logged,
/// Next milestone — the last hidden when maxed out).
///
/// Accent: yellow #FBBF24 (flame).
/// Gold #D4A017 highlights the "Last logged" value when it reads "Today".
struct LoggingStreakCard: View {
    let loggingCurrent: Int
    let loggingLongest: Int
    let loggingLastDate: String?

    private let yellowAccent = Color(hex: 0xFBBF24)
    private let goldHighlight = Color(hex: 0xD4A017)

    private var lastLoggedLabel: String {
        StreakLabels.lastLogged(loggingLastDate: loggingLastDate)
    }
    private var isToday: Bool { lastLoggedLabel == "Today" }
    private var nextMilestone: Int? {
        StreakMilestones.nextLogging(after: loggingCurrent)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerRow
            bigNumber
            Divider().background(SikaTheme.Color.mutedForeground.opacity(0.15))
            detailsBlock
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SikaTheme.Color.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(SikaTheme.Color.mutedForeground.opacity(0.15), lineWidth: 1)
        )
    }

    private var headerRow: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(yellowAccent.opacity(0.10))
                    .frame(width: 32, height: 32)
                Image(systemName: "flame.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(yellowAccent)
            }
            Text("LOGGING")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.5)
                .foregroundStyle(SikaTheme.Color.mutedForeground)
            Spacer()
        }
    }

    private var bigNumber: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("\(loggingCurrent)")
                .font(SikaTheme.Typography.sans(40, weight: .bold))
                .foregroundStyle(SikaTheme.Color.foreground)
                .monospacedDigit()
            Text(loggingCurrent == 1 ? "day" : "days")
                .font(SikaTheme.Typography.sans(14))
                .foregroundStyle(SikaTheme.Color.mutedForeground)
        }
    }

    private var detailsBlock: some View {
        VStack(spacing: 8) {
            detailRow(label: "Longest", value: "\(loggingLongest) days")
            detailRow(
                label: "Last logged",
                value: lastLoggedLabel,
                valueColor: isToday ? goldHighlight : nil
            )
            if let milestone = nextMilestone {
                let toGo = milestone - loggingCurrent
                detailRow(
                    label: "Next milestone",
                    value: "\(milestone) days (\(toGo) to go)"
                )
            }
        }
    }

    private func detailRow(
        label: String,
        value: String,
        valueColor: Color? = nil
    ) -> some View {
        HStack {
            Text(label)
                .font(SikaTheme.Typography.sans(13))
                .foregroundStyle(SikaTheme.Color.mutedForeground)
            Spacer()
            Text(value)
                .font(SikaTheme.Typography.sans(13, weight: .semibold))
                .foregroundStyle(valueColor ?? SikaTheme.Color.foreground)
                .monospacedDigit()
        }
    }
}
