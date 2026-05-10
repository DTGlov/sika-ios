import SwiftUI

/// 5-frequency chip grid (Daily / Weekly / Bi-weekly / Monthly / Yearly).
/// Active chip: green #00D9A3 border + 10% bg + green fg.
/// Selecting a new frequency resets `scheduleDay` to nil (caller's binding).
struct FrequencyChipsView: View {
    @Binding var selected: RecurringFrequency
    /// Closure invoked when the user picks a different frequency. Caller
    /// uses it to reset scheduleDay.
    let onChange: (RecurringFrequency) -> Void

    private let greenColor = Color(hex: 0x00D9A3)

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(RecurringFrequency.allCases, id: \.self) { freq in
                chip(freq)
            }
        }
    }

    private func chip(_ freq: RecurringFrequency) -> some View {
        let isActive = selected == freq
        return Button {
            if selected != freq {
                selected = freq
                onChange(freq)
            }
        } label: {
            Text(freq.displayLabel)
                .font(SikaTheme.Typography.sans(13, weight: isActive ? .semibold : .regular))
                .foregroundStyle(isActive ? greenColor : SikaTheme.Color.foreground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isActive ? greenColor.opacity(0.10) : SikaTheme.Color.card)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            isActive ? greenColor : SikaTheme.Color.border,
                            lineWidth: isActive ? 1.5 : 1
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

extension RecurringFrequency {
    var displayLabel: String {
        switch self {
        case .daily:    return "Daily"
        case .weekly:   return "Weekly"
        case .biweekly: return "Bi-weekly"
        case .monthly:  return "Monthly"
        case .yearly:   return "Yearly"
        }
    }
}
