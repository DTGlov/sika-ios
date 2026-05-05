import Foundation
import Supabase

enum SupabaseConfig {
    static var url: URL {
        guard let raw = Bundle.main.infoDictionary?["SUPABASE_URL"] as? String,
              !raw.isEmpty,
              let url = URL(string: raw) else {
            fatalError("SUPABASE_URL is missing or invalid in Info.plist. Check Sika.xcconfig.")
        }
        return url
    }

    static var anonKey: String {
        guard let raw = Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String,
              !raw.isEmpty else {
            fatalError("SUPABASE_ANON_KEY is missing or empty in Info.plist. Check Sika.xcconfig.")
        }
        return raw
    }
}

final class SupabaseManager {
    static let shared = SupabaseManager()

    let client: SupabaseClient

    private init() {
        self.client = SupabaseClient(
            supabaseURL: SupabaseConfig.url,
            supabaseKey: SupabaseConfig.anonKey
        )
    }

    func pingHealth() async -> Bool {
        let healthURL = SupabaseConfig.url.appendingPathComponent("auth/v1/health")
        var request = URLRequest(url: healthURL)
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.timeoutInterval = 10
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse {
                return (200..<300).contains(http.statusCode)
            }
            return false
        } catch {
            return false
        }
    }
}
