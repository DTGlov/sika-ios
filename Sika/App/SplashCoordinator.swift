import Foundation
import SwiftUI
import Observation

/// Manages the animated SwiftUI splash overlay (Phase 9.5d).
///
/// State machine:
///  - At init, `isShowing = true`, `mode` pinned via timestamp window,
///    `minimumAnimationComplete = false`, and the splash overlay
///    mounts above `RootView`.
///  - The splash view runs its assemble timeline and, on reaching its
///    minimum-duration mark, calls `animationDidComplete(criticalDataReady:)`.
///  - Independently, `AppState.criticalDataReady` flips to true once
///    the bootstrap path resolves Home-renderable state. The splash
///    view observes this via `.onChange` and forwards it as
///    `dataDidBecomeReady()`.
///  - The splash exits only when BOTH minimum animation and data
///    are ready. `performExit()` flips `isShowing = false` inside a
///    `withAnimation`, which drives:
///     * the splash view's removal `.transition(scale + opacity)`
///     * the root content's scale-in + fade-in modifiers
@Observable
@MainActor
final class SplashCoordinator {
    enum SplashMode {
        case cold      // Full assemble (~1.6s)
        case warm      // Abbreviated (~700ms total including exit)
        case skipped   // Currently unused — placeholder
    }

    /// Drives mount/unmount of the splash overlay + the root content's
    /// scale/fade. Flipping to false starts the exit transition.
    var isShowing: Bool = true

    /// Pinned at init; the animation timeline reads this once.
    private(set) var mode: SplashMode

    /// True once the splash view reports its assemble + hold reached
    /// the minimum-duration mark. Read by `dataDidBecomeReady()` to
    /// decide whether to exit on data-ready or wait.
    private(set) var minimumAnimationComplete: Bool = false

    private static let lastLaunchKey = "splash.last_launch_timestamp"
    private static let warmWindowSeconds: TimeInterval = 600  // 10 min

    init() {
        self.mode = Self.detectMode()
        Self.markLaunched()
    }

    private static func detectMode() -> SplashMode {
        let now = Date().timeIntervalSince1970
        let last = UserDefaults.standard.double(forKey: lastLaunchKey)
        if last > 0 && (now - last) < warmWindowSeconds {
            return .warm
        }
        return .cold
    }

    private static func markLaunched() {
        UserDefaults.standard.set(
            Date().timeIntervalSince1970,
            forKey: lastLaunchKey
        )
    }

    /// Splash view calls this after assemble + hold completes.
    /// Exits immediately if data is also ready; otherwise records the
    /// completion and waits for `dataDidBecomeReady()` to fire.
    func animationDidComplete(criticalDataReady: Bool) {
        minimumAnimationComplete = true
        if criticalDataReady {
            performExit()
        }
    }

    /// Splash view calls this when `AppState.criticalDataReady` flips
    /// to true. Exits if min animation is already done; otherwise
    /// no-op (animationDidComplete will pick it up).
    func dataDidBecomeReady() {
        if minimumAnimationComplete {
            performExit()
        }
    }

    private func performExit() {
        withAnimation(.easeIn(duration: 0.3)) {
            isShowing = false
        }
    }

    #if DEBUG
    /// DEV-only: replay the cold splash without killing the app.
    /// Resets gating flags so the next assemble runs from scratch.
    /// Bypasses the warm-window check so replays always run the full
    /// assemble for visual review.
    func replayAsCold() {
        mode = .cold
        minimumAnimationComplete = false
        isShowing = true
    }
    #endif
}
