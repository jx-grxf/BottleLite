import Foundation

protocol WineRuntimeProbing {
    func detectRuntime() -> RuntimeStatus
}

struct WineRuntimeProbe: WineRuntimeProbing {
    private let fileManager: FileManager

    /// Candidate Wine binaries, most specific first. Modern Wine (10+) ships a
    /// single `wine` binary, so `wine64` is only a fallback for older installs.
    static let candidatePaths = [
        "/opt/homebrew/bin/wine",
        "/opt/homebrew/bin/wine64",
        "/usr/local/bin/wine",
        "/usr/local/bin/wine64",
        "/Applications/Wine Stable.app/Contents/Resources/wine/bin/wine",
        "/Applications/Wine Stable.app/Contents/Resources/wine/bin/wine64",
    ]

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func detectRuntime() -> RuntimeStatus {
        guard let path = Self.candidatePaths.first(where: fileManager.isExecutableFile(atPath:)) else {
            return RuntimeStatus(
                state: .missing,
                message: "No Wine runtime found yet.",
                winePath: nil,
                version: nil
            )
        }

        let version = Self.readVersion(at: path)
        return RuntimeStatus(
            state: .ready,
            message: version.map { "\($0) detected." } ?? "Wine runtime detected.",
            winePath: path,
            version: version
        )
    }

    /// Reads the Wine version string (e.g. "Wine 10.0") via `wine --version`.
    /// Returns `nil` if the probe fails so callers can degrade gracefully.
    static func readVersion(at path: String) -> String? {
        guard
            let output = Shell.run(path, ["--version"], timeout: 8),
            output.succeeded
        else {
            return nil
        }

        let raw = output.trimmedOutput
        guard !raw.isEmpty else { return nil }

        // `wine --version` prints e.g. "wine-10.0" or "wine-9.0 (Staging)".
        let normalized =
            raw
            .replacingOccurrences(of: "wine-", with: "Wine ")
            .replacingOccurrences(of: "wine ", with: "Wine ")
        return normalized.hasPrefix("Wine") ? normalized : "Wine \(raw)"
    }
}
