import SwiftUI

/// Emerald motif — four horizontal sinusoidal waves.
/// Per audit lines 359-388. Each wave is a chain of quadratic curves
/// that alternate above/below the baseline. Drawn into a 100×50 logical
/// space (wider-than-tall aspect).
struct EmeraldMotif: View {
    let strokeColor: Color
    /// Display size — width-leaning aspect (waves are horizontal).
    var width: CGFloat = 200
    var height: CGFloat = 100
    var strokeWidth: CGFloat = 0.8

    var body: some View {
        Canvas { context, canvasSize in
            let sx = canvasSize.width / 100.0
            let sy = canvasSize.height / 50.0
            // Use min so stroke width doesn't get stretched too thin/thick.
            let strokeS = min(sx, sy)

            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                CGPoint(x: x * sx, y: y * sy)
            }

            // 4 baselines at y=10, 20, 30, 40
            // Wave amplitude: 5. Each segment spans 20 units in x; control point
            // is 10 units in (mid-segment) at y ± amplitude.
            let baselines: [CGFloat] = [10, 20, 30, 40]
            let amplitude: CGFloat = 5
            let segmentWidth: CGFloat = 20

            for (idx, baseY) in baselines.enumerated() {
                var path = Path()
                path.move(to: p(0, baseY))

                // Alternate direction by row so adjacent waves are out of phase
                let startsUp = (idx % 2 == 0)
                var goingUp = startsUp

                var x: CGFloat = 0
                while x < 100 {
                    let nextX = x + segmentWidth
                    let midX = x + segmentWidth / 2
                    let controlY = baseY + (goingUp ? -amplitude : amplitude)
                    path.addQuadCurve(to: p(nextX, baseY), control: p(midX, controlY))
                    x = nextX
                    goingUp.toggle()
                }

                context.stroke(
                    path,
                    with: .color(strokeColor),
                    style: StrokeStyle(lineWidth: strokeWidth * strokeS, lineCap: .round)
                )
            }
        }
        .frame(width: width, height: height)
    }
}
