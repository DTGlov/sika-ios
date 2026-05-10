import SwiftUI

/// 2-tab segmented strip with count chips. Active tab uses an accent color
/// per tab kind: red (#F43F5E) for Recurring, amber (#FBBF24) for Paused.
struct RecurringTabsView: View {
    @Binding var selected: AppState.RecurringTab
    let recurringCount: Int
    let pausedCount: Int

    private let redColor = Color(hex: 0xF43F5E)
    private let amberColor = Color(hex: 0xFBBF24)

    var body: some View {
        HStack(spacing: 4) {
            tab(.expense, label: "Recurring", count: recurringCount, accent: redColor)
            tab(.paused, label: "Paused", count: pausedCount, accent: amberColor)
        }
        .padding(4)
        .background(SikaTheme.Color.muted)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(SikaTheme.Color.border, lineWidth: 1)
        )
    }

    private func tab(
        _ tab: AppState.RecurringTab,
        label: String,
        count: Int,
        accent: Color
    ) -> some View {
        let isActive = selected == tab
        return Button {
            selected = tab
        } label: {
            HStack(spacing: 8) {
                Text(label)
                    .font(SikaTheme.Typography.sans(13, weight: isActive ? .semibold : .regular))
                    .foregroundStyle(isActive ? accent : SikaTheme.Color.mutedForeground)
                Text("\(count)")
                    .font(.system(size: 11, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(isActive ? accent : SikaTheme.Color.mutedForeground.opacity(0.8))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        isActive
                            ? accent.opacity(0.18)
                            : SikaTheme.Color.border
                    )
                    .clipShape(Capsule())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(isActive ? SikaTheme.Color.card : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}
