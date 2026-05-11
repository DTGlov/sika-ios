import SwiftUI

/// SwiftUI splash overlay (Phase 9.5d).
///
/// Renders the same cowrie primitives as SikaMark — ellipse body,
/// spine line, 4 rib V-pairs — but with per-element animation state
/// so the cowrie "assembles" after the storyboard handoff.
///
/// Handoff design: the launch storyboard already shows the cowrie
/// at the same position and size. To avoid the cowrie disappearing
/// on takeover, the body stays fully visible at frame 0 — only the
/// spine and ribs are added during the animation.
///
/// Exit gating (Phase 9.5d fix): the view's timeline ends with
/// `coordinator.animationDidComplete(criticalDataReady:)`. The
/// coordinator exits only when BOTH that callback has fired AND
/// `AppState.criticalDataReady == true`. The view also observes
/// the AppState flag and forwards changes to the coordinator so
/// the slow-network case (animation finishes first, data later)
/// exits cleanly as soon as data lands.
///
/// The scale-and-fade exit itself is provided by the parent's
/// `.transition(.scale(scale: 1.05).combined(with: .opacity))` plus
/// the coordinator's `withAnimation` around the `isShowing` flip —
/// not a local @State on this view.
///
/// Timeline (cold, ~1.3s before gate):
///   0 – 200ms     Hold (body-only, storyboard match)
///   200 – 600     Spine draws top-to-bottom (easeInOut)
///   600 – 1100    4 ribs staggered out (100ms apart, 200ms each)
///   1100 – 1300   Hold at full cowrie
///   1300+         `animationDidComplete` fires; exits if data ready
///
/// Timeline (warm, ~400ms before gate):
///   0 – 100ms     Hold
///   100 – 300     Spine + 4 ribs appear together (easeOut)
///   300 – 400     Hold
///   400+          `animationDidComplete` fires; exits if data ready
struct AnimatedSplashView: View {
    @Environment(SplashCoordinator.self) private var coordinator
    @Environment(AppState.self) private var appState

    // Body is visible from frame 0 to seam with the launch storyboard.
    // No fade-in on body; only spine + ribs animate.
    @State private var spineProgress: Double = 0
    @State private var ribProgress: [Double] = [0, 0, 0, 0]

    private let bodyColor   = Color(hex: 0xD4A017)
    private let strokeColor = Color(hex: 0x0E1A2E)
    private let bgColor     = Color(hex: 0x0E1A2E)

    /// Matches the launch storyboard's UIImageName display size so
    /// the storyboard → SwiftUI handoff has no jump.
    private let cowrieSize: CGFloat = 280

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            Canvas { context, size in
                drawCowrie(context: context, size: size)
            }
            .frame(width: cowrieSize, height: cowrieSize)
        }
        .onAppear {
            Task { await playAnimation() }
        }
        .onChange(of: appState.criticalDataReady) { _, ready in
            if ready {
                coordinator.dataDidBecomeReady()
            }
        }
    }

    // MARK: - Drawing (replicates SikaMark primitives with progress)

    private func drawCowrie(context: GraphicsContext, size: CGSize) {
        let scale = size.width / 48.0
        let cx = size.width / 2
        let cy = size.height / 2

        // BODY — gold ellipse, always fully visible at frame 0
        let bodyRect = CGRect(
            x: cx - 14 * scale,
            y: cy - 20 * scale,
            width: 28 * scale,
            height: 40 * scale
        )
        context.fill(Path(ellipseIn: bodyRect), with: .color(bodyColor))

        // SPINE — draws from top (y=6s) to bottom (y=42s)
        if spineProgress > 0 {
            let yTop = cy - 18 * scale          // 24s - 6s above center
            let yBot = cy + 18 * scale          // 42s - 24s below center
            let yEnd = yTop + (yBot - yTop) * spineProgress
            var path = Path()
            path.move(to: CGPoint(x: cx, y: yTop))
            path.addLine(to: CGPoint(x: cx, y: yEnd))
            context.stroke(
                path,
                with: .color(strokeColor),
                style: StrokeStyle(lineWidth: 2.5 * scale, lineCap: .round)
            )
        }

        // RIBS — 4 V-pairs, each opening from a point at (24s, yStart)
        //         out to (22s, yEnd) and (26s, yEnd) over its progress
        let ribDefs: [(yStart: CGFloat, yEnd: CGFloat)] = [
            (12, 16), (18, 22), (24, 28), (30, 34)
        ]
        for (idx, def) in ribDefs.enumerated() {
            let progress = ribProgress[idx]
            guard progress > 0 else { continue }

            let originY = cy + (def.yStart - 24) * scale
            let yDelta = (def.yEnd - def.yStart) * scale * progress
            let xDelta = 2 * scale * progress

            var left = Path()
            left.move(to: CGPoint(x: cx, y: originY))
            left.addLine(to: CGPoint(x: cx - xDelta, y: originY + yDelta))

            var right = Path()
            right.move(to: CGPoint(x: cx, y: originY))
            right.addLine(to: CGPoint(x: cx + xDelta, y: originY + yDelta))

            let ribStyle = StrokeStyle(lineWidth: 1.5 * scale, lineCap: .round)
            context.stroke(left,  with: .color(strokeColor), style: ribStyle)
            context.stroke(right, with: .color(strokeColor), style: ribStyle)
        }
    }

    // MARK: - Timeline

    private func playAnimation() async {
        switch coordinator.mode {
        case .cold:    await playColdAnimation()
        case .warm:    await playWarmAnimation()
        case .skipped: coordinator.animationDidComplete(criticalDataReady: appState.criticalDataReady)
        }
    }

    private func playColdAnimation() async {
        // Phase 1: hold body-only (200ms — storyboard handoff)
        try? await Task.sleep(for: .milliseconds(200))

        // Phase 2: spine draws (400ms)
        withAnimation(.easeInOut(duration: 0.4)) {
            spineProgress = 1.0
        }
        try? await Task.sleep(for: .milliseconds(400))

        // Phase 3: 4 ribs staggered, 100ms apart, each 200ms
        for idx in 0..<4 {
            withAnimation(.easeOut(duration: 0.2)) {
                ribProgress[idx] = 1.0
            }
            try? await Task.sleep(for: .milliseconds(100))
        }
        // After 4 × 100ms staggers, the last rib has 100ms left to run.
        try? await Task.sleep(for: .milliseconds(100))

        // Phase 4: hold at full cowrie (200ms)
        try? await Task.sleep(for: .milliseconds(200))

        // Gate the exit on data-ready. Static cowrie holds at full
        // opacity until data lands — no spinner, no pulse, no text.
        coordinator.animationDidComplete(
            criticalDataReady: appState.criticalDataReady
        )
    }

    private func playWarmAnimation() async {
        // Brief body-only hold
        try? await Task.sleep(for: .milliseconds(100))

        // Spine + ribs appear together
        withAnimation(.easeOut(duration: 0.2)) {
            spineProgress = 1.0
            ribProgress = [1, 1, 1, 1]
        }
        try? await Task.sleep(for: .milliseconds(200))

        // Brief hold
        try? await Task.sleep(for: .milliseconds(100))

        coordinator.animationDidComplete(
            criticalDataReady: appState.criticalDataReady
        )
    }
}
