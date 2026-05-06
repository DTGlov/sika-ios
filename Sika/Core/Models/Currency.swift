import Foundation

struct Currency: Identifiable, Equatable, Hashable {
    let code: String
    let name: String
    let symbol: String

    var id: String { code }
}
