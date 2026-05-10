import SwiftUI

/// 7-button row (Sun..Sat). Single-letter labels. Index 0 = Sunday.
/// Active button: green #00D9A3 bg + dark text. Inactive: muted.
struct DayOfWeekPickerView: View {
    @Binding var selectedDay: Int?

    private let greenColor = Color(hex: 0x00D9A3)
    private let darkText = Color(hex: 0x0E1A2E)
    private let labels = ["S", "M", "T", "W", "T", "F", "S"]
    private let fullNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<7, id: \.self) { index in
                button(index: index)
            }
        }
    }

    private func button(index: Int) -> some View {
        let isActive = selectedDay == index
        return Button {
            selectedDay = index
        } label: {
            Text(labels[index])
                .font(SikaTheme.Typography.sans(13, weight: .semibold))
                .foregroundStyle(isActive ? darkText : SikaTheme.Color.mutedForeground)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(isActive ? greenColor : SikaTheme.Color.muted)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(fullNames[index])
    }
}
