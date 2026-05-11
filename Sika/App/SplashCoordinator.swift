import Foundation
import SwiftUI
import Observation

/// Manages the animated SwiftUI splash overlay (Phase 9.5d).
///
/// Two pieces of state:
///  - `isShowing` — drives the overlay mount/unmount + the scale/fade
///    that the SikaApp root applies to its content.
///  - `mode` — pinned at construction time. Drives the animation
///    timeline inside `AnimatedSplashView`.
///
/// Warm vs cold detection uses a UserDefaults timestamp written on
/// each launch; a re-open within `warmWindowSeconds` (10 minutes) of
/// the previous launch is treated as warm. The flag is process-bound
/// in spirit — we don't need an in-memory singleton because each
/// `SikaApp.init` constructs a fresh coordinator.
@Observable
@MainActor
final class SplashCoordinator {
    enum SplashMode {
        case cold      // Full assemble (~1.6s)
        case warm      // Abbreviated (~700ms total including exit)
        case skipped   // No splash (currently unused — placeholder)
    }

    /// Drives mount/unmount of the splash overlay.
    var isShowing: Bool = true

    /// Pinned at init; the animation timeline reads this once.
    private(set) var mode: SplashMode

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

    /// Called by AnimatedSplashView when its exit transition finishes.
    /// Flips `isShowing` to false so the overlay unmounts and the root
    /// content's scale/fade animation finishes the cross-fade.
    func splashDidFinish() {
        isShowing = false
    }

    #if DEBUG
    /// DEV-only: replay the cold splash without killing the app.
    /// Bypasses the warm-window check so replays always run the full
    /// assemble for visual review.
    func replayAsCold() {
        mode = .cold
        isShowing = true
    }
    #endif
}
