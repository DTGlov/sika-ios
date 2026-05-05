import SwiftUI

@main
struct SikaApp: App {
    init() {
        print("🪙 Sika launching…")
        _ = SupabaseConfig.url
        _ = SupabaseConfig.anonKey
        print("✅ Env config loaded")

        Task {
            let ok = await SupabaseManager.shared.pingHealth()
            print(ok ? "✅ Supabase reachable" : "❌ Supabase ping failed")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
