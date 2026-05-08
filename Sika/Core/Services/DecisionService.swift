import Foundation
import Supabase

/// HTTP client for /api/decisions/ask + /api/decisions/outcome.
/// Sends Bearer token from current Supabase session on every request.
///
/// All compute (context, LLM call, persistence) happens server-side.
/// iOS is a thin transport layer.
final class DecisionService {
    static let shared = DecisionService()

    /// Production base URL. Hardcoded for now; could be plumbed via
    /// Bundle.infoDictionary if future test/staging deploys are added.
    private let baseURL = URL(string: "https://sika-dlrl.vercel.app")!

    private var client: SupabaseClient { SupabaseManager.shared.client }

    /// Calls /api/decisions/ask with Bearer auth.
    /// Returns the persisted decision id + the LLM's response payload.
    func ask(_ request: PurchaseAnalysisRequest) async throws -> AskDecisionResponse {
        let url = baseURL.appendingPathComponent("/api/decisions/ask")
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(
            "Bearer \(try currentAccessToken())",
            forHTTPHeaderField: "Authorization"
        )
        urlRequest.httpBody = try JSONEncoder().encode(request)
        urlRequest.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DecisionError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            #if DEBUG
            if let errBody = String(data: data, encoding: .utf8) {
                print("⚠️ DecisionService.ask HTTP \(httpResponse.statusCode): \(errBody)")
            }
            #endif
            throw DecisionError.serverError(status: httpResponse.statusCode)
        }

        do {
            return try JSONDecoder().decode(AskDecisionResponse.self, from: data)
        } catch {
            #if DEBUG
            print("⚠️ DecisionService.ask decode failed: \(error)")
            #endif
            throw DecisionError.decodeFailed
        }
    }

    /// Calls /api/decisions/outcome with Bearer auth.
    /// Best-effort: errors are swallowed (matches web's silent fail).
    func recordOutcome(decisionId: UUID, outcome: DecisionOutcome) async {
        do {
            let url = baseURL.appendingPathComponent("/api/decisions/outcome")
            var urlRequest = URLRequest(url: url)
            urlRequest.httpMethod = "POST"
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            urlRequest.setValue(
                "Bearer \(try currentAccessToken())",
                forHTTPHeaderField: "Authorization"
            )

            struct OutcomeBody: Encodable {
                let decision_id: String
                let outcome: String
            }
            urlRequest.httpBody = try JSONEncoder().encode(
                OutcomeBody(
                    decision_id: decisionId.uuidString,
                    outcome: outcome.rawValue
                )
            )
            urlRequest.timeoutInterval = 10

            _ = try await URLSession.shared.data(for: urlRequest)
        } catch {
            #if DEBUG
            print("⚠️ DecisionService.recordOutcome failed (silent): \(error)")
            #endif
        }
    }

    /// Reads the current Supabase session's access token.
    /// Throws if no session is available — should be impossible from
    /// Home (user must be signed in to see the button at all).
    private func currentAccessToken() throws -> String {
        guard let session = client.auth.currentSession else {
            throw DecisionError.noSession
        }
        return session.accessToken
    }

    enum DecisionError: Error {
        case invalidResponse
        case serverError(status: Int)
        case decodeFailed
        case noSession
    }
}
