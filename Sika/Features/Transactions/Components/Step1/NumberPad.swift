import SwiftUI
import UIKit

/// Custom number pad for Add Transaction's amount input.
/// 4 rows × 3 cols. Layout matches web exactly.
struct NumberPad: View {
    let onDigitTap: (String) -> Void
    let onBackspaceTap: () -> Void

    private let layout: [[NumberPadKey]] = [
        [.digit("1"), .digit("2"), .digit("3")],
        [.digit("4"), .digit("5"), .digit("6")],
        [.digit("7"), .digit("8"), .digit("9")],
        [.digit("."), .digit("0"), .backspace]
    ]

    var body: some View {
        VStack(spacing: SikaTheme.Spacing.sm) {
            ForEach(0..<layout.count, id: \.self) { row in
                HStack(spacing: SikaTheme.Spacing.sm) {
                    ForEach(0..<layout[row].count, id: \.self) { col in
                        keyButton(for: layout[row][col])
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func keyButton(for key: NumberPadKey) -> some View {
        switch key {
        case .digit(let value):
            NumberPadKeyButton(action: { onDigitTap(value) }) {
                Text(value)
                    .font(SikaTheme.Typography.mono(28, weight: .bold))
                    .foregroundStyle(SikaTheme.Color.foreground)
            }
        case .backspace:
            NumberPadKeyButton(action: onBackspaceTap) {
                Image(systemName: "delete.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(SikaTheme.Color.foreground)
            }
        }
    }
}

private enum NumberPadKey {
    case digit(String)
    case backspace
}

private struct NumberPadKeyButton<Content: View>: View {
    let action: () -> Void
    @ViewBuilder let content: () -> Content
    @State private var isPressed = false

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            content()
                .frame(maxWidth: .infinity, minHeight: 64)
                .background(SikaTheme.Color.muted)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .scaleEffect(isPressed ? 0.96 : 1.0)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isPressed)
    }
}
