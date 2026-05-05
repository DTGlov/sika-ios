import Foundation
import Supabase

enum AuthSignUpResult {
    case sessionCreated(Session)
    case verificationRequired(email: String)
}

enum AuthError: LocalizedError {
    case emailNotConfirmed(email: String)
    case invalidCredentials
    case networkError
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .emailNotConfirmed: return "Email not confirmed"
        case .invalidCredentials: return "Invalid email or password"
        case .networkError: return "Network error — check your connection"
        case .unknown(let message): return message
        }
    }
}

struct AuthService {
    private var auth: AuthClient { SupabaseManager.shared.client.auth }

    func signIn(email: String, password: String) async throws -> Session {
        do {
            return try await auth.signIn(email: email, password: password)
        } catch {
            throw Self.translate(error, fallbackEmail: email)
        }
    }

    func signUp(email: String, password: String, fullName: String) async throws -> AuthSignUpResult {
        let response = try await auth.signUp(
            email: email,
            password: password,
            data: ["full_name": .string(fullName)]
        )
        if let session = response.session {
            return .sessionCreated(session)
        }
        return .verificationRequired(email: email)
    }

    func signOut() async throws {
        try await auth.signOut()
    }

    func currentSession() async -> Session? {
        auth.currentSession
    }

    func resendVerificationEmail(email: String) async throws {
        try await auth.resend(email: email, type: .signup)
    }

    func observeAuthChanges(_ handler: @escaping (AuthChangeEvent, Session?) -> Void) async -> Task<Void, Never> {
        let stream = auth.authStateChanges
        return Task {
            for await change in stream {
                if Task.isCancelled { break }
                handler(change.event, change.session)
            }
        }
    }

    private static func translate(_ error: Error, fallbackEmail: String) -> Error {
        let message = error.localizedDescription.lowercased()
        if message.contains("email not confirmed") {
            return AuthError.emailNotConfirmed(email: fallbackEmail)
        }
        if message.contains("invalid login credentials") {
            return AuthError.invalidCredentials
        }
        let urlError = error as? URLError
        if urlError != nil {
            return AuthError.networkError
        }
        return AuthError.unknown(error.localizedDescription)
    }
}
