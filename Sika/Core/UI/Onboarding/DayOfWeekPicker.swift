import SwiftUI

/// 7-column picker for day-of-week. Sunday = 0 (matches web).
struct DayOfWeekPicker: View {
    @Binding var selection: Int?

    private let labels = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        HStack(spacing: SikaTheme.Spacing.xs) {
            ForEach(0..<7, id: \.self) { index in
                Button {
                    selection = index
                } label: {
                    Text(labels[index])
                        .font(SikaTheme.Typography.sans(14, weight: .semibold))
                        .foregroundStyle(foreground(for: index))
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(background(for: index))
                        .overlay(
                            RoundedRectangle(cornerRadius: SikaTheme.Radius.md)
                                .stroke(border(for: index), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: SikaTheme.Radius.md))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func foreground(for index: Int) -> Color {
        selection == index ? SikaTheme.Color.primaryForeground : SikaTheme.Color.mutedForeground
    }

    private func background(for index: Int) -> Color {
        selection == index ? SikaTheme.Color.primary : SikaTheme.Color.muted
    }

    private func border(for index: Int) -> Color {
        selection == index ? SikaTheme.Color.primary : SikaTheme.Color.border
    }
}
