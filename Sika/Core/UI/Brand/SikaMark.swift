import SwiftUI

struct SikaMark: View {
    enum Variant { case goldOnNavy, goldOnCream }

    var size: CGFloat = 48
    var variant: Variant = .goldOnNavy

    private var strokeColor: Color { Color(hex: 0x0E1A2E) }
    private var bodyColor: Color { Color(hex: 0xD4A017) }

    var body: some View {
        Canvas { context, canvasSize in
            let s = canvasSize.width / 48.0
            let cx = 24 * s
            let cy = 24 * s

            let bodyRect = CGRect(x: cx - 14*s, y: cy - 20*s, width: 28*s, height: 40*s)
            context.fill(Path(ellipseIn: bodyRect), with: .color(bodyColor))

            var spine = Path()
            spine.move(to: CGPoint(x: 24*s, y: 6*s))
            spine.addLine(to: CGPoint(x: 24*s, y: 42*s))
            context.stroke(spine, with: .color(strokeColor),
                           style: StrokeStyle(lineWidth: 2.5*s, lineCap: .round))

            let ribY: [(start: CGFloat, end: CGFloat)] = [
                (12, 16), (18, 22), (24, 28), (30, 34)
            ]
            var ribs = Path()
            for (yStart, yEnd) in ribY {
                ribs.move(to: CGPoint(x: 24*s, y: yStart*s))
                ribs.addLine(to: CGPoint(x: 22*s, y: yEnd*s))
                ribs.move(to: CGPoint(x: 24*s, y: yStart*s))
                ribs.addLine(to: CGPoint(x: 26*s, y: yEnd*s))
            }
            context.stroke(ribs, with: .color(strokeColor),
                           style: StrokeStyle(lineWidth: 1.5*s, lineCap: .round))
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Sika")
    }
}

#Preview {
    VStack(spacing: 20) {
        SikaMark(size: 48)
        SikaMark(size: 80)
        SikaMark(size: 120)
    }
    .padding()
    .background(SikaTheme.Color.background)
}
