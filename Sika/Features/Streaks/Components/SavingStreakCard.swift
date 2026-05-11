import SwiftUI

/// Saving streak stat card. Same shape as `LoggingStreakCard` but with
/// gold accent (#D4A017), `dollarsign.circle.fill` icon, weeks unit,
/// and "Last contributed" / "This week" labels.
///
/// Gold highlights the "Last contributed" value when it reads "This week".
struct SavingStreakCard: View {
    let savingsCurrent: Int
    let savingsLongest: Int
    let savingsLastWeek: String?

    private let goldAccent = Color(hex: 0xD4A017)

    private var lastSavedLabel: String {
        StreakLabels.lastSaved(savingsLastWeek: savingsLastWeek)
    }
    private var isThisWeek: Bool { lastSavedLabel == "This week" }
    private var nextMilestone: Int? {
        StreakMilestones.nextSavings(after: savingsCurrent)
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
                    .fill(goldAccent.opacity(0.10))
                    .frame(width: 32, height: 32)
                Image(systemName: "dollarsign.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(goldAccent)
            }
            Text("SAVING")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.5)
                .foregroundStyle(SikaTheme.Color.mutedForeground)
            Spacer()
        }
    }

    private var bigNumber: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("\(savingsCurrent)")
                .font(SikaTheme.Typography.sans(40, weight: .bold))
                .foregroundStyle(SikaTheme.Color.foreground)
                .monospacedDigit()
            Text(savingsCurrent == 1 ? "week" : "weeks")
                .font(SikaTheme.Typography.sans(14))
                .foregroundStyle(SikaTheme.Color.mutedForeground)
        }
    }

    private var detailsBlock: some View {
        VStack(spacing: 8) {
            detailRow(label: "Longest", value: "\(savingsLongest) weeks")
            detailRow(
                label: "Last contributed",
                value: lastSavedLabel,
                valueColor: isThisWeek ? goldAccent : nil
            )
            if let milestone = nextMilestone {
                let toGo = milestone - savingsCurrent
                detailRow(
                    label: "Next milestone",
                    value: "\(milestone) weeks (\(toGo) to go)"
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
