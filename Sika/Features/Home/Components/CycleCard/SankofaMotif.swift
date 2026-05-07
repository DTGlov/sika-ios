import SwiftUI

/// Sankofa adinkra motif rendered with SwiftUI Path.
///
/// PHASE 1 IMPLEMENTATION NOTE:
/// The web reference (src/components/cycle-card/motifs.tsx) uses a complex
/// SVG path. This iOS implementation is a stylized approximation —
/// concentric arcs with a curved beak — that conveys the "looking back"
/// motion of the Sankofa bird without being a literal port.
///
/// Phase 6 polish will replace this with a faithful path-data port from
/// the web SVG.
struct SankofaMotif: View {
    let strokeColor: Color
    var size: CGFloat = 96
    var strokeWidth: CGFloat = 2.5

    var body: some View {
        Canvas { context, canvasSize in
            let s = canvasSize.width / 96.0
            let cx = 48 * s
            let cy = 48 * s

            // Outer ring
            let outerRect = CGRect(x: cx - 38*s, y: cy - 38*s, width: 76*s, height: 76*s)
            context.stroke(
                Path(ellipseIn: outerRect),
                with: .color(strokeColor),
                style: StrokeStyle(lineWidth: strokeWidth*s, lineCap: .round)
            )

            // Inner arc (looking-back curve)
            var innerArc = Path()
            innerArc.addArc(
                center: CGPoint(x: cx, y: cy),
                radius: 22 * s,
                startAngle: .degrees(220),
                endAngle: .degrees(70),
                clockwise: false
            )
            context.stroke(
                innerArc,
                with: .color(strokeColor),
                style: StrokeStyle(lineWidth: strokeWidth*s, lineCap: .round)
            )

            // Tail curve (beak/return motion)
            var tail = Path()
            tail.move(to: CGPoint(x: cx + 18*s, y: cy + 18*s))
            tail.addQuadCurve(
                to: CGPoint(x: cx - 8*s, y: cy + 30*s),
                control: CGPoint(x: cx + 22*s, y: cy + 34*s)
            )
            context.stroke(
                tail,
                with: .color(strokeColor),
                style: StrokeStyle(lineWidth: strokeWidth*s, lineCap: .round)
            )

            // Beak dot
            let dotRect = CGRect(x: cx - 11*s, y: cy + 27*s, width: 6*s, height: 6*s)
            context.fill(Path(ellipseIn: dotRect), with: .color(strokeColor))
        }
        .frame(width: size, height: size)
    }
}
