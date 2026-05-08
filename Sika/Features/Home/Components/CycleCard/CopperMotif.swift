import SwiftUI

/// Copper motif — five sweeping arcs from the top-right corner.
/// Stylized port of audit lines 326-356; uses Path.addArc for clean curves.
/// Anchor: top-right of the container.
struct CopperMotif: View {
    let strokeColor: Color
    var size: CGFloat = 96
    var strokeWidth: CGFloat = 1.4

    /// Each arc spans roughly the upper-right quadrant. Web's SVG values:
    /// (start, end) pairs with decreasing radii. We approximate by drawing
    /// arcs from a fixed anchor at top-right with descending radii.
    var body: some View {
        Canvas { context, canvasSize in
            let s = canvasSize.width / 100.0
            let anchorX = canvasSize.width   // top-right corner
            let anchorY: CGFloat = 0

            let arcs: [(radius: CGFloat, startAngle: Double, endAngle: Double)] = [
                // Largest arc, sweeping from top-right downward to far-left edge
                (radius: 90, startAngle: 180, endAngle: 90),
                (radius: 80, startAngle: 175, endAngle: 95),
                (radius: 70, startAngle: 170, endAngle: 100),
                (radius: 60, startAngle: 165, endAngle: 105),
                (radius: 50, startAngle: 160, endAngle: 110)
            ]

            for arc in arcs {
                var path = Path()
                path.addArc(
                    center: CGPoint(x: anchorX, y: anchorY),
                    radius: arc.radius * s,
                    startAngle: .degrees(arc.startAngle),
                    endAngle: .degrees(arc.endAngle),
                    clockwise: true
                )
                context.stroke(
                    path,
                    with: .color(strokeColor),
                    style: StrokeStyle(lineWidth: strokeWidth * s, lineCap: .round)
                )
            }
        }
        .frame(width: size, height: size)
    }
}
