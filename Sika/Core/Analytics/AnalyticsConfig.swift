import Foundation

enum AnalyticsConfig {
    static var apiKey: String {
        guard let key = Bundle.main.infoDictionary?["POSTHOG_API_KEY"] as? String,
              !key.isEmpty else {
            fatalError("Missing POSTHOG_API_KEY in Info.plist (check Sika.xcconfig)")
        }
        return key
    }

    static var host: String {
        guard let host = Bundle.main.infoDictionary?["POSTHOG_HOST"] as? String,
              !host.isEmpty else {
            return "https://us.i.posthog.com"
        }
        return host
    }

    /// Session replay default: ON in DEBUG, OFF in release.
    /// Release can be flipped per-user via `ios_session_replay_enabled`
    /// feature flag set in PostHog dashboard.
    static var sessionReplayDefault: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
}
