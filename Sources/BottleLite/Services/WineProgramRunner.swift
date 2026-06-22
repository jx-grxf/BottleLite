import Foundation

protocol ProgramRunning {
    @discardableResult
    func launch(
        program: WindowsProgram,
        bottle: Bottle,
        winePath: String,
        gameMode: Bool,
        terminationHandler: @escaping @Sendable (ProgramTermination) -> Void
    ) throws -> ProgramLaunch

    func stop(_ launch: ProgramLaunch) throws
}

/// Handle for a running Windows program. Retains the underlying `Process` so it
/// can be terminated cleanly and exposes the log file capturing its output.
final class ProgramLaunch {
    let processID: Int32
    let logURL: URL?
    private let process: Process

    init(process: Process, logURL: URL?) {
        self.process = process
        self.processID = process.processIdentifier
        self.logURL = logURL
    }

    func terminate() {
        if process.isRunning {
            process.terminate()
        }
    }
}

struct ProgramTermination: Equatable, Sendable {
    let status: Int32

    func message(for programName: String) -> String {
        status == 0
            ? "\(programName) finished."
            : "\(programName) exited with code \(status)."
    }
}

enum ProgramRunError: LocalizedError {
    case executableMissing

    var errorDescription: String? {
        switch self {
        case .executableMissing:
            "The executable could not be found on disk anymore."
        }
    }
}

struct WineProgramRunner: ProgramRunning {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    @discardableResult
    func launch(
        program: WindowsProgram,
        bottle: Bottle,
        winePath: String,
        gameMode: Bool = false,
        terminationHandler: @escaping @Sendable (ProgramTermination) -> Void
    ) throws -> ProgramLaunch {
        let executableURL = URL(filePath: program.path)
        guard fileManager.fileExists(atPath: executableURL.path) else {
            throw ProgramRunError.executableMissing
        }

        Self.ensureSteamConfig(forExecutableAt: executableURL, fileManager: fileManager)

        let prefixURL = try BottleStorage.prefixURL(for: bottle, using: fileManager)
        let logURL = try? BottleStorage.logURL(for: program, in: bottle, using: fileManager)

        let process = Process()
        process.executableURL = URL(filePath: winePath)
        process.arguments =
            [program.path] + Self.parseArguments(program.arguments)
            + Self.injectedArguments(
                forExecutableAt: executableURL, userArguments: program.arguments,
                fileManager: fileManager)
        process.currentDirectoryURL = Self.workingDirectory(for: executableURL)
        process.environment = launchEnvironment(
            prefixURL: prefixURL, winePath: winePath, gameMode: gameMode,
            graphicsBackend: bottle.graphicsBackend)
        if gameMode {
            // Ask the scheduler for responsive, non-throttled CPU time.
            process.qualityOfService = .userInitiated
        }

        if let logHandle = logURL.flatMap({ makeLogHandle(at: $0, program: program) }) {
            process.standardOutput = logHandle
            process.standardError = logHandle
        }

        process.terminationHandler = { process in
            try? (process.standardOutput as? FileHandle)?.close()
            terminationHandler(ProgramTermination(status: process.terminationStatus))
        }

        try process.run()
        return ProgramLaunch(process: process, logURL: logURL)
    }

    /// Subfolder names that hold an executable but are *not* the directory the
    /// program expects as its working directory. Many games (AssaultCube,
    /// Unreal `Binaries/Win64`, …) load data relative to the game root and must
    /// run from the parent of their `bin`/arch folder.
    static let binSubfolders: Set<String> = [
        "bin", "bin_win32", "bin_win64", "bin32", "bin64", "binaries", "win32", "win64",
    ]

    /// Extra arguments BottleLite injects for known-problematic executables so
    /// they "just work" the way CrossOver/Whisky special-case them. Skipped if
    /// the user already passed overlapping flags.
    ///
    /// Steam: under a Game Porting Toolkit Wine the 64-bit `steamwebhelper`
    /// (Steam's embedded Chromium) crash-loops with repeated NOTREACHED and the
    /// client window never appears. The community fix is to force the 32-bit
    /// web helper and allow all OS architectures — `-allosarches
    /// -cef-force-32bit`. See mybyways.com "Running Steam in Game Porting
    /// Toolkit".
    static func injectedArguments(
        forExecutableAt url: URL, userArguments: String, fileManager: FileManager = .default
    ) -> [String] {
        guard url.lastPathComponent.lowercased() == "steam.exe" else { return [] }
        let lower = userArguments.lowercased()
        guard !lower.contains("-cef"), !lower.contains("-allosarches") else { return [] }
        // Only apply the 32-bit-CEF workaround once Steam has bootstrapped its
        // CEF component (its `bin/cef` exists). Forcing 32-bit CEF on the very
        // first run — before that component has downloaded — can block the
        // bootstrap the workaround itself depends on. Same gate as steam.cfg.
        let steamDir = url.deletingLastPathComponent()
        guard fileManager.fileExists(atPath: steamDir.appending(path: "bin/cef").path) else {
            return []
        }
        // Force the 32-bit web helper (the 64-bit one crash-loops on GPTK) AND
        // disable its GPU/compositing path (the offscreen render context can't be
        // created under Wine) — the union of the two documented Steam-on-Wine
        // fixes, matching Steam's own "restart with GPU acceleration disabled".
        return ["-allosarches", "-cef-force-32bit", "-cef-disable-gpu", "-cef-disable-gpu-compositing"]
    }

    /// Steam's bootstrapper loops on "Background update loop checking for
    /// update" under Wine and never hands off to the client. A `steam.cfg` next
    /// to `Steam.exe` with `BootStrapperInhibitAll=Enable` stops that loop.
    ///
    /// Only written once Steam has already bootstrapped its client (its `bin/cef`
    /// folder exists). Writing it before the first run would block the initial
    /// component download (including the 32-bit CEF that -cef-force-32bit needs).
    /// Best-effort. See mybyways.com GPTK guide.
    static func ensureSteamConfig(forExecutableAt url: URL, fileManager: FileManager = .default) {
        guard url.lastPathComponent.lowercased() == "steam.exe" else { return }
        let steamDir = url.deletingLastPathComponent()
        guard fileManager.fileExists(atPath: steamDir.appending(path: "bin/cef").path) else { return }
        let configURL = steamDir.appending(path: "steam.cfg")
        guard !fileManager.fileExists(atPath: configURL.path) else { return }
        try? "BootStrapperInhibitAll=Enable\n".write(to: configURL, atomically: true, encoding: .utf8)
    }

    /// Splits a raw argument string into argv tokens, honoring single and double
    /// quotes so paths with spaces survive (e.g. `-config "My Game/cfg.ini"`).
    static func parseArguments(_ raw: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var quote: Character?
        var hasToken = false

        for character in raw {
            if let active = quote {
                if character == active {
                    quote = nil
                } else {
                    current.append(character)
                }
            } else if character == "\"" || character == "'" {
                quote = character
                hasToken = true
            } else if character.isWhitespace {
                if hasToken {
                    tokens.append(current)
                    current = ""
                    hasToken = false
                }
            } else {
                current.append(character)
                hasToken = true
            }
        }
        if hasToken { tokens.append(current) }
        return tokens
    }

    /// Chooses the working directory for a program: the executable's folder,
    /// climbing out of up to two nested `bin`/arch subfolders so data files load.
    static func workingDirectory(for executable: URL) -> URL {
        var directory = executable.deletingLastPathComponent()
        for _ in 0..<2 where binSubfolders.contains(directory.lastPathComponent.lowercased()) {
            directory = directory.deletingLastPathComponent()
        }
        return directory
    }

    func stop(_ launch: ProgramLaunch) throws {
        launch.terminate()
    }

    /// Creates (or truncates) a per-launch log file and returns an append-mode
    /// handle seeded with a small header so the file is never empty/confusing.
    private func makeLogHandle(at url: URL, program: WindowsProgram) -> FileHandle? {
        let header = "BottleLite launch log for \(program.name)\n\(program.path)\n\n"
        guard
            (try? header.data(using: .utf8)?.write(to: url)) != nil,
            let handle = try? FileHandle(forWritingTo: url)
        else {
            return nil
        }
        _ = try? handle.seekToEnd()
        return handle
    }

    /// Combined `WINEDLLOVERRIDES`: always disable winemenubuilder, plus the
    /// translation layer's overrides when a non-default backend is selected.
    static func dllOverrides(for backend: GraphicsBackend) -> String {
        var parts = ["winemenubuilder.exe=d"]
        if let overrides = backend.dllOverrides {
            parts.append(overrides)
        }
        return parts.joined(separator: ";")
    }

    private func launchEnvironment(
        prefixURL: URL, winePath: String, gameMode: Bool, graphicsBackend: GraphicsBackend
    ) -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        // Ensure helper binaries that live alongside `wine` (wineserver,
        // wineboot) are resolvable when Wine shells out internally. PATH must
        // prepend to the inherited value, so it's handled here rather than in
        // the shared builder.
        let wineBin = URL(filePath: winePath).deletingLastPathComponent().path
        if let existingPath = environment["PATH"], !existingPath.isEmpty {
            environment["PATH"] = "\(wineBin):\(existingPath)"
        } else {
            environment["PATH"] = wineBin
        }

        for (key, value) in Self.wineEnvironment(
            prefixPath: prefixURL.path, winePath: winePath, gameMode: gameMode,
            graphicsBackend: graphicsBackend)
        {
            environment[key] = value
        }
        return environment
    }

    /// The Wine-specific variables BottleLite layers on top of the inherited
    /// process environment for a launch: the prefix, debug muting, the chosen
    /// graphics backend's DLL overrides (so `winemenubuilder` stays off and the
    /// D3DMetal/DXVK overrides are applied), Game Mode tuning, and the backend's
    /// library search paths. Shared by the in-app runner and the generated
    /// `.app` launchers so a program behaves identically however it's started.
    /// (PATH is intentionally excluded — it must prepend to the inherited value.)
    static func wineEnvironment(
        prefixPath: String, winePath: String, gameMode: Bool, graphicsBackend: GraphicsBackend
    ) -> [String: String] {
        var env: [String: String] = [
            "WINEPREFIX": prefixPath,
            "WINEDEBUG": "-all",
            "WINEDLLOVERRIDES": dllOverrides(for: graphicsBackend),
        ]
        if gameMode {
            for (key, value) in gameModeEnvironment {
                env[key] = value
            }
            // WINE_LARGE_ADDRESS_AWARE lets a 32-bit process allocate above 2GB.
            // On a Game Porting Toolkit (Wow64) Wine that overflows Wine's
            // page-protection table and crashes 32-bit games with an
            // `alloc_pages_vprot` assertion (virtual.c). It's a no-op for 64-bit
            // apps anyway, so only apply it on a non-GPTK Wine where it's safe
            // and actually helps older 32-bit titles.
            if !GamingRuntime.isGPTKWine(winePath) {
                env["WINE_LARGE_ADDRESS_AWARE"] = "1"
            }
        }
        // Point Wine at MoltenVK / GPTK so the selected graphics backend can
        // actually use them (no-op for the built-in renderer).
        for (key, value) in GamingRuntime.environment(for: graphicsBackend) {
            env[key] = value
        }
        return env
    }

    /// Performance-oriented environment applied on top of the base launch
    /// environment when Game Mode is enabled. Honored by Wine builds on macOS
    /// (msync/esync) and the Apple Metal HUD. `WINE_LARGE_ADDRESS_AWARE` is
    /// deliberately *not* here — it's applied conditionally in `wineEnvironment`
    /// because it crashes 32-bit games on a GPTK Wine.
    static let gameModeEnvironment: [String: String] = [
        "WINEMSYNC": "1",
        "WINEESYNC": "1",
        // Apple's Metal performance HUD (FPS / frame time overlay).
        "MTL_HUD_ENABLED": "1",
    ]
}
