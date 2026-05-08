import SwiftUI

/// Amber motif — 13 stardust dots + 1 eight-point compass star.
/// Per audit lines 390-435. All shapes are filled with the motif color.
/// Container: half-width on the right side, anchored top.
struct AmberMotif: View {
    let strokeColor: Color
    var size: CGFloat = 96

    /// Dot positions and radii in 100-unit logical space.
    /// (cx, cy, radius)
    private let dots: [(CGFloat, CGFloat, CGFloat)] = [
        (40, 15, 1.5),
        (60, 8,  2.0),
        (75, 18, 1.0),
        // (85, 12) is also the compass star anchor; the small dot
        // is replaced by the star
        (95, 22, 1.2),
        (50, 32, 1.5),
        (72, 28, 2.0),
        (88, 36, 1.0),
        (42, 48, 1.5),
        (68, 52, 1.2),
        (90, 47, 1.8),
        (58, 68, 2.0),
        (82, 72, 1.2)
    ]

    /// Compass-star anchor in logical space.
    private let starCenter: (CGFloat, CGFloat) = (85, 12)
    private let starRadius: CGFloat = 4

    var body: some View {
        Canvas { context, canvasSize in
            let s = canvasSize.width / 100.0

            // Render 12 stardust dots
            for (cx, cy, r) in dots {
                let scaledR = r * s
                let rect = CGRect(
                    x: cx * s - scaledR,
                    y: cy * s - scaledR,
                    width: scaledR * 2,
                    height: scaledR * 2
                )
                context.fill(Path(ellipseIn: rect), with: .color(strokeColor))
            }

            // 8-point compass star at (85, 12) — 8 vertices alternating
            // outer (radius 4) and inner (radius 1) points.
            let starCx = starCenter.0 * s
            let starCy = starCenter.1 * s
            var starPath = Path()
            for i in 0..<8 {
                let angle = Double(i) * .pi / 4 - .pi / 2  // start at top
                let r = (i % 2 == 0 ? starRadius : 1.0) * s
                let x = starCx + CGFloat(cos(angle)) * r
                let y = starCy + CGFloat(sin(angle)) * r
                if i == 0 {
                    starPath.move(to: CGPoint(x: x, y: y))
                } else {
                    starPath.addLine(to: CGPoint(x: x, y: y))
                }
            }
            starPath.closeSubpath()
            context.fill(starPath, with: .color(strokeColor))
        }
        .frame(width: size, height: size)
    }
}
