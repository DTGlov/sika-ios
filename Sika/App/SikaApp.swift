import SwiftUI

@main
struct SikaApp: App {
    @State private var appState: AppState
    @State private var toastManager: ToastManager
    @State private var splashCoordinator: SplashCoordinator

    init() {
        print("🪙 Sika launching…")
        _ = SupabaseConfig.url
        _ = SupabaseConfig.anonKey
        print("✅ Env config loaded")

        #if DEBUG
        let geistFonts = UIFont.familyNames.filter { $0.contains("Geist") }
        print("📝 Registered Geist families: \(geistFonts)")
        #endif

        AnalyticsService.shared.bootstrap()

        let firstLaunch = !UserDefaults.standard.bool(forKey: "sika.has_launched_before")
        if firstLaunch {
            UserDefaults.standard.set(true, forKey: "sika.has_launched_before")
        }
        AnalyticsService.shared.capture(.appLaunched(firstLaunch: firstLaunch))

        let appState = AppState()
        let toastManager = ToastManager()
        let splashCoordinator = SplashCoordinator()
        self._appState = State(initialValue: appState)
        self._toastManager = State(initialValue: toastManager)
        self._splashCoordinator = State(initialValue: splashCoordinator)

        Task {
            let ok = await SupabaseManager.shared.pingHealth()
            print(ok ? "✅ Supabase reachable" : "❌ Supabase ping failed")
        }
    }

var body: some Scene {
    WindowGroup {
        ZStack {
            // Root content. Hidden while splash is visible so the user
            // perceives a single cowrie cross-fading into the app. The
            // 0.95 → 1.0 scale-in pairs with the splash's 1.0 → 1.05
            // scale-out to create the cross-fade effect.
            RootView()
                .sikaToastOverlay()
                .environment(appState)
                .environment(toastManager)
                .environment(splashCoordinator)
                .task { await appState.bootstrap() }
                .scaleEffect(splashCoordinator.isShowing ? 0.95 : 1.0)
                .opacity(splashCoordinator.isShowing ? 0 : 1)
                .animation(
                    .easeOut(duration: 0.3),
                    value: splashCoordinator.isShowing
                )

            // Splash overlay — animated cowrie on navy.
            // The scale-up + fade exit is owned by `.transition` here
            // (not local @State on the view) so the coordinator's
            // `withAnimation { isShowing = false }` drives both the
            // splash's removal and the root content's cross-fade-in
            // through the same animation curve.
            if splashCoordinator.isShowing {
                AnimatedSplashView()
                    .environment(appState)
                    .environment(splashCoordinator)
                    .transition(.scale(scale: 1.05).combined(with: .opacity))
            }
        }
    }
}
}
