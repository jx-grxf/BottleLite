import Foundation

protocol WineRuntimeProbing {
    func detectRuntime() -> RuntimeStatus
}

struct WineRuntimeProbe: WineRuntimeProbing {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func detectRuntime() -> RuntimeStatus {
        let candidates = [
            "/opt/homebrew/bin/wine64",
            "/opt/homebrew/bin/wine",
            "/usr/local/bin/wine64",
            "/usr/local/bin/wine"
        ]

        if let path = candidates.first(where: fileManager.isExecutableFile(atPath:)) {
            return RuntimeStatus(
                state: .ready,
                message: "Wine runtime detected.",
                winePath: path
            )
        }

        return RuntimeStatus(
            state: .missing,
            message: "No Wine runtime found yet.",
            winePath: nil
        )
    }
}
