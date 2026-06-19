import Foundation

struct RuntimeStatus: Equatable {
    var state: RuntimeState
    var message: String
    var winePath: String?
    var version: String?

    static let unknown = RuntimeStatus(
        state: .unknown,
        message: "Checking Wine runtime...",
        winePath: nil,
        version: nil
    )

    /// A short, human-friendly description of the detected runtime, e.g.
    /// "Wine 10.0" — falls back to the status message when unknown.
    var displayName: String {
        guard let version, !version.isEmpty else { return message }
        return version
    }
}

enum RuntimeState: Equatable {
    case ready
    case missing
    case unknown
}

enum WineInstallState: Equatable {
    case idle
    case installing
    case waitingForTerminal
    case failed(String)

    var isBusy: Bool {
        switch self {
        case .installing, .waitingForTerminal:
            true
        case .idle, .failed:
            false
        }
    }
}
