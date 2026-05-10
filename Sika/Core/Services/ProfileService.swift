import Foundation
import Supabase

private struct ProfileOnboardingUpdate: Encodable {
    let monthlyIncome: Decimal
    let currency: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case monthlyIncome = "monthly_income"
        case currency
        case updatedAt = "updated_at"
    }
}

enum ProfileServiceError: LocalizedError {
    case notSignedIn
    case profileMissing
    case requestFailed
    case serverError(status: Int)

    var errorDescription: String? {
        switch self {
        case .notSignedIn: return "Not signed in."
        case .profileMissing: return "We couldn't find your profile. Please contact support."
        case .requestFailed: return "Request failed. Check your connection."
        case .serverError(let status): return "Server error (\(status))."
        }
    }
}

struct ProfileService {
    private var client: SupabaseClient { SupabaseManager.shared.client }

    func fetchCurrentProfile() async throws -> Profile {
        guard let userId = client.auth.currentUser?.id else {
            throw ProfileServiceError.notSignedIn
        }
        do {
            let response: PostgrestResponse<Profile> = try await client
                .from("profiles")
                .select()
                .eq("id", value: userId)
                .single()
                .execute()
            return response.value
        } catch let decodingError as DecodingError {
            #if DEBUG
            logProfileDecodeError(decodingError)
            #endif
            throw decodingError
        } catch {
            #if DEBUG
            print("⚠️ ProfileService fetch error (non-decoding): \(error)")
            #endif
            throw error
        }
    }

    /// Update profile after onboarding completes. Sets monthly_income + currency
    /// and bumps updated_at. Returns the refreshed profile.
    func updateAfterOnboarding(monthlyIncome: Decimal, currency: String) async throws -> Profile {
        guard let userId = client.auth.currentUser?.id else {
            throw ProfileServiceError.notSignedIn
        }
        let payload = ProfileOnboardingUpdate(
            monthlyIncome: monthlyIncome,
            currency: currency,
            updatedAt: ISO8601DateFormatter().string(from: Date())
        )
        let response: PostgrestResponse<Profile> = try await client
            .from("profiles")
            .update(payload)
            .eq("id", value: userId)
            .select()
            .single()
            .execute()
        return response.value
    }

    // MARK: - Phase S1 (Settings) — config mutations

    /// Hardcoded base URL for HTTP routes that require server-side service-role
    /// privileges or validation that RLS can't enforce. Mirrors Phase 8's
    /// DecisionService base URL.
    private static let apiBaseURL = URL(string: "https://sika-dlrl.vercel.app")!

    /// PATCH /api/profile/theme — server-side validates 'light' | 'dark'.
    /// Requires Bearer auth (web prereq: feat/bearer-auth-profile).
    func updateTheme(_ theme: SystemTheme) async throws {
        try await patchJSON(path: "/api/profile/theme", body: ["theme": theme.rawValue])
    }

    /// PATCH /api/profile/haptics
    func updateHaptics(_ enabled: Bool) async throws {
        try await patchJSON(path: "/api/profile/haptics", body: ["enabled": enabled])
    }

    /// PATCH /api/profile/currency
    func updateCurrency(_ code: String) async throws {
        try await patchJSON(path: "/api/profile/currency", body: ["currency_code": code])
    }

    /// DELETE /api/profile/delete — cascades 17 user-scoped tables + profiles
    /// + auth.users via the service-role endpoint. Requires Bearer auth.
    func deleteAccount() async throws {
        try await sendDelete(path: "/api/profile/delete")
    }

    /// Budget Month + Budget Split — direct Supabase write (RLS-scoped).
    /// Single update covers all 4 fields together.
    func updateBudgetConfig(
        userId: UUID,
        cycleStartDay: Int,
        needsPercent: Decimal,
        wantsPercent: Decimal,
        savingsPercent: Decimal
    ) async throws {
        struct Payload: Encodable {
            let cycle_start_day: Int
            let needs_percent: Decimal
            let wants_percent: Decimal
            let savings_percent: Decimal
            let updated_at: String
        }
        try await client
            .from("profiles")
            .update(Payload(
                cycle_start_day: cycleStartDay,
                needs_percent: needsPercent,
                wants_percent: wantsPercent,
                savings_percent: savingsPercent,
                updated_at: ISO8601DateFormatter().string(from: Date())
            ))
            .eq("id", value: userId)
            .execute()
    }

    // MARK: - HTTP helpers

    private func patchJSON(path: String, body: [String: Any]) async throws {
        let url = Self.apiBaseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(try currentAccessToken())", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data, path: path)
    }

    private func sendDelete(path: String) async throws {
        let url = Self.apiBaseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(try currentAccessToken())", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data, path: path)
    }

    private func validate(response: URLResponse, data: Data, path: String) throws {
        guard let http = response as? HTTPURLResponse else {
            throw ProfileServiceError.requestFailed
        }
        guard (200..<300).contains(http.statusCode) else {
            #if DEBUG
            if let body = String(data: data, encoding: .utf8) {
                print("⚠️ ProfileService \(path) HTTP \(http.statusCode): \(body)")
            }
            #endif
            throw ProfileServiceError.serverError(status: http.statusCode)
        }
    }

    private func currentAccessToken() throws -> String {
        guard let session = client.auth.currentSession else {
            throw ProfileServiceError.notSignedIn
        }
        return session.accessToken
    }

    #if DEBUG
    private func logProfileDecodeError(_ error: DecodingError) {
        print("❌ Profile decode failed:")
        switch error {
        case .keyNotFound(let key, let context):
            print("   - Missing key: \(key.stringValue)")
            print("   - Path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
        case .typeMismatch(let type, let context):
            print("   - Type mismatch: expected \(type)")
            print("   - Path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
            print("   - Detail: \(context.debugDescription)")
        case .valueNotFound(let type, let context):
            print("   - Null value where \(type) expected")
            print("   - Path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
        case .dataCorrupted(let context):
            print("   - Data corrupted: \(context.debugDescription)")
            print("   - Path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))")
        @unknown default:
            print("   - Unknown decoding error: \(error)")
        }
    }
    #endif
}
