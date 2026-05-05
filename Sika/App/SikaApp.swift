import SwiftUI

@main
struct SikaApp: App {
    @State private var appState: AppState
    @State private var toastManager: ToastManager

    init() {
        print("🪙 Sika launching…")
        _ = SupabaseConfig.url
        _ = SupabaseConfig.anonKey
        print("✅ Env config loaded")

        #if DEBUG
        let geistFonts = UIFont.familyNames.filter { $0.contains("Geist") }
        print("📝 Registered Geist families: \(geistFonts)")
        #endif

        let appState = AppState()
        let toastManager = ToastManager()
        self._appState = State(initialValue: appState)
        self._toastManager = State(initialValue: toastManager)

        Task {
            let ok = await SupabaseManager.shared.pingHealth()
            print(ok ? "✅ Supabase reachable" : "❌ Supabase ping failed")
        }
    }

var body: some Scene {
    WindowGroup {
        RootView()
            .sikaToastOverlay()
            .environment(appState)
            .environment(toastManager)
            .task { await appState.bootstrap() }
    }
}
}
