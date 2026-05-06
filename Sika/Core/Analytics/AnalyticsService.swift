import Foundation
import PostHog
import Observation

@Observable
@MainActor
final class AnalyticsService {
    static let shared = AnalyticsService()

    private var initialized = false

    private init() {}

    /// Call ONCE at app launch.
    func bootstrap() {
        guard !initialized else { return }
        initialized = true

        let config = PostHogConfig(
            apiKey: AnalyticsConfig.apiKey,
            host: AnalyticsConfig.host
        )

        config.captureApplicationLifecycleEvents = false
        config.flushAt = 20
        config.flushIntervalSeconds = 30

        config.sessionReplay = AnalyticsConfig.sessionReplayDefault

        PostHogSDK.shared.setup(config)
        PostHogSDK.shared.register([
            "$ios_platform": "ios"
        ])

        #if DEBUG
        print("📊 PostHog initialized — host: \(AnalyticsConfig.host)")
        print("📊 Session replay default: \(AnalyticsConfig.sessionReplayDefault)")
        #endif
    }

    /// Call after sign-in or sign-up success.
    func identify(userId: String, name: String?, email: String?) {
        var properties: [String: Any] = [:]
        if let name { properties["name"] = name }
        if let email { properties["email"] = email }
        PostHogSDK.shared.identify(userId, userProperties: properties.isEmpty ? nil : properties)

        #if DEBUG
        print("📊 identify: \(userId) \(properties)")
        #endif
    }

    /// Call on sign-out.
    func reset() {
        PostHogSDK.shared.reset()
        #if DEBUG
        print("📊 reset")
        #endif
    }

    /// Capture an event. Type-safe via AnalyticsEvent enum.
    func capture(_ event: AnalyticsEvent) {
        if let properties = event.properties {
            PostHogSDK.shared.capture(event.name, properties: properties)
        } else {
            PostHogSDK.shared.capture(event.name)
        }

        #if DEBUG
        if let properties = event.properties {
            print("📊 \(event.name) \(properties)")
        } else {
            print("📊 \(event.name)")
        }
        #endif
    }

    /// Re-evaluate session replay against feature flag (call after identify).
    /// In release builds, replay is OFF unless `ios_session_replay_enabled` is
    /// true for this user via PostHog flags.
    func reconcileSessionReplay() {
        #if DEBUG
        return
        #else
        PostHogSDK.shared.reloadFeatureFlags { [weak self] in
            _ = self
            let enabled = PostHogSDK.shared.isFeatureEnabled("ios_session_replay_enabled")
            if enabled {
                PostHogSDK.shared.startSessionRecording()
            }
        }
        #endif
    }
}
