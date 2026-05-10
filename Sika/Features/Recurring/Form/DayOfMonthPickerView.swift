import SwiftUI

/// Day-of-month picker for monthly frequency.
/// Side-by-side: number input (1...28, clamped on input) + Last day toggle.
/// Both UI elements bind to the same `selectedDay` state.
/// - selectedDay >= 1: number input shows that value, Last-day toggle off.
/// - selectedDay == -1: Last-day toggle active, number input empty.
/// - selectedDay == nil: both empty.
struct DayOfMonthPickerView: View {
    @Binding var selectedDay: Int?

    @State private var text: String = ""

    private let greenColor = Color(hex: 0x00D9A3)
    private let darkText = Color(hex: 0x0E1A2E)

    var body: some View {
        HStack(spacing: 8) {
            numberInput
            Text("or")
                .font(SikaTheme.Typography.sans(11))
                .foregroundStyle(SikaTheme.Color.mutedForeground)
            lastDayToggle
        }
        .onAppear { syncTextFromBinding() }
        .onChange(of: selectedDay) { _, _ in syncTextFromBinding() }
    }

    private var numberInput: some View {
        HStack(spacing: 6) {
            Text("Day")
                .font(SikaTheme.Typography.sans(11))
                .foregroundStyle(SikaTheme.Color.mutedForeground)
            TextField("1–28", text: $text)
                .keyboardType(.numberPad)
                .font(SikaTheme.Typography.sans(15, weight: .semibold))
                .foregroundStyle(SikaTheme.Color.foreground)
                .frame(width: 56)
                .multilineTextAlignment(.center)
                .onChange(of: text) { _, newValue in
                    handleTextChange(newValue)
                }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(SikaTheme.Color.card)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    selectedDay != nil && selectedDay != -1
                        ? greenColor
                        : SikaTheme.Color.border,
                    lineWidth: 1
                )
        )
    }

    private var lastDayToggle: some View {
        let isActive = selectedDay == -1
        return Button {
            if isActive {
                selectedDay = nil
            } else {
                selectedDay = -1
                text = ""
            }
        } label: {
            Text("Last day")
                .font(SikaTheme.Typography.sans(13, weight: .semibold))
                .foregroundStyle(isActive ? darkText : SikaTheme.Color.foreground)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(isActive ? greenColor : SikaTheme.Color.card)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            isActive ? greenColor : SikaTheme.Color.border,
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private func handleTextChange(_ newValue: String) {
        let filtered = newValue.filter { $0.isNumber }
        if filtered.isEmpty {
            if selectedDay != -1 { selectedDay = nil }
            if text != filtered { text = filtered }
            return
        }
        if let parsed = Int(filtered) {
            let clamped = min(max(parsed, 1), 28)
            selectedDay = clamped
            let clampedText = String(clamped)
            if text != clampedText { text = clampedText }
        }
    }

    private func syncTextFromBinding() {
        if let day = selectedDay, day >= 1 {
            let value = String(day)
            if text != value { text = value }
        } else if selectedDay == -1 {
            if text != "" { text = "" }
        } else {
            if text != "" { text = "" }
        }
    }
}
