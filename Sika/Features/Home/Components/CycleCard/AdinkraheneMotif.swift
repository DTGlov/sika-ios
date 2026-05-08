import SwiftUI

/// Adinkrahene adinkra motif — three concentric circles with a center dot.
/// "Chief of symbols" — represents leadership and greatness.
/// Stylized port of web's SVG; pure stroked rings + filled center.
struct AdinkraheneMotif: View {
    let strokeColor: Color
    var size: CGFloat = 96
    var strokeWidth: CGFloat = 2.0

    var body: some View {
        Canvas { context, canvasSize in
            let s = canvasSize.width / 100.0
            let cx = canvasSize.width / 2
            let cy = canvasSize.height / 2

            // 3 concentric rings (radii 44, 30, 16 in 100-unit space)
            for radius in [44.0, 30.0, 16.0] {
                let r = radius * s
                let rect = CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)
                context.stroke(
                    Path(ellipseIn: rect),
                    with: .color(strokeColor),
                    style: StrokeStyle(lineWidth: strokeWidth * s)
                )
            }

            // Center dot (radius 3.5 in 100-unit space)
            let dotR = 3.5 * s
            let dotRect = CGRect(x: cx - dotR, y: cy - dotR, width: dotR * 2, height: dotR * 2)
            context.fill(Path(ellipseIn: dotRect), with: .color(strokeColor))
        }
        .frame(width: size, height: size)
    }
}
