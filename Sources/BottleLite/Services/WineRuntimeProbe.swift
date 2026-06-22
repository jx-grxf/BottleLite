import Foundation

protocol WineRuntimeProbing {
    func detectRuntime() -> RuntimeStatus
    /// Every distinct Wine binary installed, most preferred first, for the
    /// per-bottle runtime picker.
    func detectAllRuntimes() -> [DetectedRuntime]
}

extension WineRuntimeProbing {
    func detectAllRuntimes() -> [DetectedRuntime] { [] }
}

/// One installed Wine binary the user can pick for a bottle.
struct DetectedRuntime: Identifiable, Equatable, Sendable {
    let path: String
    let version: String?

    var id: String { path }
    var isGPTK: Bool { GamingRuntime.isGPTKWine(path) }

    /// Human-readable label, e.g. "Wine 7.7 (Game Porting Toolkit 1.1)" or a
    /// trimmed path when the version couldn't be read.
    var label: String {
        if let version, !version.isEmpty { return version }
        return URL(filePath: path).deletingLastPathComponent().deletingLastPathComponent()
            .lastPathComponent
    }
}

struct WineRuntimeProbe: WineRuntimeProbing {
    private let fileManager: FileManager

    /// Candidate Wine binaries, most preferred first. Gaming-capable builds
    /// (Apple's Game Porting Toolkit, Gcenx's CrossOver-based Wine) come before
    /// plain Homebrew Wine so D3DMetal/DXVK have a runtime that supports them.
    static let candidatePaths = [
        // Gcenx Game Porting Toolkit (prebuilt CrossOver Wine + D3DMetal). This
        // is the build that runs the modern Steam client and DX12 games.
        GamingRuntime.gptkAppWine64,
        // Apple's Game Porting Toolkit (source build via Homebrew)
        "/opt/homebrew/opt/game-porting-toolkit/bin/wine64",
        "/usr/local/opt/game-porting-toolkit/bin/wine64",
        // Gcenx CrossOver-based Wine
        "/Applications/Wine Crossover.app/Contents/Resources/wine/bin/wine64",
        "/Applications/Wine Crossover.app/Contents/Resources/wine/bin/wine",
        // Plain Homebrew / Wine Stable
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

    func detectAllRuntimes() -> [DetectedRuntime] {
        var seenRealPaths = Set<String>()
        var runtimes: [DetectedRuntime] = []
        for path in Self.candidatePaths where fileManager.isExecutableFile(atPath: path) {
            // Dedup symlinks (e.g. /opt/homebrew/bin/wine64 → the GPTK app) by
            // resolved real path, keeping the higher-preference candidate.
            let real = URL(filePath: path).resolvingSymlinksInPath().path
            guard seenRealPaths.insert(real).inserted else { continue }
            runtimes.append(DetectedRuntime(path: path, version: Self.readVersion(at: path)))
        }
        return runtimes
    }

    /// Reads the Wine version string (e.g. "Wine 10.0") via `wine --version`.
    /// Returns `nil` if the probe fails so callers can degrade gracefully.
    ///
    /// The result is cached per binary path for the app's lifetime: `detectRuntime`
    /// runs on every program launch (and from `@MainActor`), and spawning
    /// `wine --version` each time blocks the UI for up to the timeout. The version
    /// only changes when Wine is reinstalled, which restarts the app anyway.
    static func readVersion(at path: String) -> String? {
        if let cached = versionCache.value(for: path) { return cached }

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
        let version = normalized.hasPrefix("Wine") ? normalized : "Wine \(raw)"
        versionCache.set(version, for: path)
        return version
    }

    private static let versionCache = VersionCache()
}

/// Tiny thread-safe path→version cache so the `wine --version` subprocess runs
/// at most once per binary per app session.
private final class VersionCache: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: String] = [:]

    func value(for key: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return values[key]
    }

    func set(_ value: String, for key: String) {
        lock.lock()
        defer { lock.unlock() }
        values[key] = value
    }
}
