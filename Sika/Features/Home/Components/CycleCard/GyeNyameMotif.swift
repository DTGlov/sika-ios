import SwiftUI

/// Gye Nyame adinkra motif — "Except God".
/// Stylized port: vertical spine + two inward curls + two crossbars.
/// Per audit lines 270-296; SwiftUI quad-curve approximations of the
/// original SVG cubic beziers.
struct GyeNyameMotif: View {
    let strokeColor: Color
    var size: CGFloat = 96
    var strokeWidth: CGFloat = 1.8

    var body: some View {
        Canvas { context, canvasSize in
            let s = canvasSize.width / 100.0
            let cx = canvasSize.width / 2
            let cy = canvasSize.height / 2

            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                CGPoint(x: cx + x * s, y: cy + y * s)
            }

            let strokeStyle = StrokeStyle(lineWidth: strokeWidth * s, lineCap: .round, lineJoin: .round)
            let spineStyle = StrokeStyle(lineWidth: 2.0 * s, lineCap: .round)
            let crossStyle = StrokeStyle(lineWidth: 1.5 * s, lineCap: .round)

            // Vertical spine: (0,-44) to (0,44)
            var spine = Path()
            spine.move(to: p(0, -44))
            spine.addLine(to: p(0, 44))
            context.stroke(spine, with: .color(strokeColor), style: spineStyle)

            // Top curl: open spiral curling left then back to spine.
            // Approximated with 2 quad curves chained.
            var topCurl = Path()
            topCurl.move(to: p(0, -42))
            topCurl.addQuadCurve(to: p(-12, 8), control: p(-40, -20))
            topCurl.addQuadCurve(to: p(3, -6), control: p(8, 4))
            context.stroke(topCurl, with: .color(strokeColor), style: strokeStyle)

            // Bottom curl: mirror image of top, curling right.
            var bottomCurl = Path()
            bottomCurl.move(to: p(0, 40))
            bottomCurl.addQuadCurve(to: p(12, -10), control: p(40, 18))
            bottomCurl.addQuadCurve(to: p(-3, 4), control: p(-8, -6))
            context.stroke(bottomCurl, with: .color(strokeColor), style: strokeStyle)

            // Top crossbar: (-9,-33) to (9,-33)
            var topCross = Path()
            topCross.move(to: p(-9, -33))
            topCross.addLine(to: p(9, -33))
            context.stroke(topCross, with: .color(strokeColor), style: crossStyle)

            // Bottom crossbar: (-9,33) to (9,33)
            var bottomCross = Path()
            bottomCross.move(to: p(-9, 33))
            bottomCross.addLine(to: p(9, 33))
            context.stroke(bottomCross, with: .color(strokeColor), style: crossStyle)
        }
        .frame(width: size, height: size)
    }
}
