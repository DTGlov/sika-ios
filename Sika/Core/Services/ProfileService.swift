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
        let response: PostgrestResponse<Profile> = try await client
            .from("profiles")
            .select()
            .eq("id", value: userId)
            .single()
            .execute()
        return response.value
    }
}
