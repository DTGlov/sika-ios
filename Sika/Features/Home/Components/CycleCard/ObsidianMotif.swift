import SwiftUI

/// Obsidian motif — five concentric circles with a center dot.
/// Variant of Adinkrahene with 5 rings instead of 3 — denser, more layered feel.
struct ObsidianMotif: View {
    let strokeColor: Color
    var size: CGFloat = 96
    var strokeWidth: CGFloat = 1.6

    var body: some View {
        Canvas { context, canvasSize in
            let s = canvasSize.width / 100.0
            let cx = canvasSize.width / 2
            let cy = canvasSize.height / 2

            // 5 concentric rings (radii 44, 34, 24, 14, 6)
            for radius in [44.0, 34.0, 24.0, 14.0, 6.0] {
                let r = radius * s
                let rect = CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)
                context.stroke(
                    Path(ellipseIn: rect),
                    with: .color(strokeColor),
                    style: StrokeStyle(lineWidth: strokeWidth * s)
                )
            }

            // Center dot (radius 2.0)
            let dotR = 2.0 * s
            let dotRect = CGRect(x: cx - dotR, y: cy - dotR, width: dotR * 2, height: dotR * 2)
            context.fill(Path(ellipseIn: dotRect), with: .color(strokeColor))
        }
        .frame(width: size, height: size)
    }
}
