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

        let prefixURL = try BottleStorage.prefixURL(for: bottle, using: fileManager)
        let logURL = try? BottleStorage.logURL(for: program, in: bottle, using: fileManager)

        let process = Process()
        process.executableURL = URL(filePath: winePath)
        process.arguments = [program.path] + Self.parseArguments(program.arguments)
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
        environment["WINEPREFIX"] = prefixURL.path
        environment["WINEDEBUG"] = "-all"
        // Stop Wine from scattering Linux .desktop/.lnk launchers on the macOS
        // Desktop (BottleLite creates real .app launchers instead), plus the
        // chosen graphics backend's DLL overrides when it isn't the built-in one.
        environment["WINEDLLOVERRIDES"] = Self.dllOverrides(for: graphicsBackend)
        // Ensure helper binaries that live alongside `wine` (wineserver,
        // wineboot) are resolvable when Wine shells out internally.
        let wineBin = URL(filePath: winePath).deletingLastPathComponent().path
        if let existingPath = environment["PATH"], !existingPath.isEmpty {
            environment["PATH"] = "\(wineBin):\(existingPath)"
        } else {
            environment["PATH"] = wineBin
        }

        if gameMode {
            for (key, value) in Self.gameModeEnvironment {
                environment[key] = value
            }
        }
        return environment
    }

    /// Performance-oriented environment applied on top of the base launch
    /// environment when Game Mode is enabled. These are honored by Wine builds
    /// on macOS (msync/esync, large-address-aware) and by the Apple Metal HUD.
    static let gameModeEnvironment: [String: String] = [
        "WINEMSYNC": "1",
        "WINEESYNC": "1",
        "WINE_LARGE_ADDRESS_AWARE": "1",
        // Apple's Metal performance HUD (FPS / frame time overlay).
        "MTL_HUD_ENABLED": "1",
    ]
}
