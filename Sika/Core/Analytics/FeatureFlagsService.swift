import Foundation
import PostHog
import Observation

/// Known feature flag keys. Add new flags here as they're created in PostHog.
/// Keys MUST match PostHog dashboard exactly.
enum FeatureFlag: String {
    case iosSessionReplayEnabled = "ios_session_replay_enabled"
    case experimentalPushNotifications = "experimental_push_notifications"
}

@Observable
@MainActor
final class FeatureFlagsService {
    static let shared = FeatureFlagsService()

    private init() {}

    func isEnabled(_ flag: FeatureFlag) -> Bool {
        PostHogSDK.shared.isFeatureEnabled(flag.rawValue)
    }

    func payload(for flag: FeatureFlag) -> Any? {
        PostHogSDK.shared.getFeatureFlagPayload(flag.rawValue)
    }

    /// Force re-fetch flags. Call after identify so flags scope to the user.
    func reload() async {
        await withCheckedContinuation { continuation in
            PostHogSDK.shared.reloadFeatureFlags {
                continuation.resume()
            }
        }
    }
}
