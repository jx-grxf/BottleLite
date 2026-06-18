import Foundation

struct RuntimeStatus: Equatable {
    var state: RuntimeState
    var message: String
    var winePath: String?

    static let unknown = RuntimeStatus(
        state: .unknown,
        message: "Checking Wine runtime...",
        winePath: nil
    )
}

enum RuntimeState: Equatable {
    case ready
    case missing
    case unknown
}
