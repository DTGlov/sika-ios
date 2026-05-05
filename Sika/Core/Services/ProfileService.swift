import Foundation
import Supabase

enum ProfileServiceError: LocalizedError {
    case notSignedIn
    case profileMissing

    var errorDescription: String? {
        switch self {
        case .notSignedIn: return "Not signed in."
        case .profileMissing: return "We couldn't find your profile. Please contact support."
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
