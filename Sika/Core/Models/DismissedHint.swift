import Foundation

/// Minimal mirror of the dismissed_hints table.
/// dismissed_at exists on the row but is never read by any client; omit.
struct DismissedHint: Codable, Equatable, Hashable {
    let userId: UUID
    let hintId: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case hintId = "hint_id"
    }
}
