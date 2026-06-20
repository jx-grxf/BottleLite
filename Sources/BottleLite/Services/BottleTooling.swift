import Foundation

/// A one-click dependency BottleLite can install into a prefix via winetricks.
struct WinetricksVerb: Identifiable, Hashable {
    var id: String { verb }
    let verb: String
    let title: String
    /// Plain-language note on what this component fixes, shown in the UI.
    let detail: String

    static let common: [WinetricksVerb] = [
        WinetricksVerb(
            verb: "corefonts", title: "Core Microsoft Fonts",
            detail: "Fixes missing or boxed-out text in many apps."),
        WinetricksVerb(
            verb: "vcrun2022", title: "Visual C++ 2015–2022 Runtime",
            detail: "Needed by most modern games and apps to start."),
        WinetricksVerb(
            verb: "dotnet48", title: ".NET Framework 4.8",
            detail: "Required by apps built on Microsoft .NET."),
        WinetricksVerb(
            verb: "dxvk", title: "DXVK (Direct3D → Vulkan)",
            detail: "Better graphics performance for DirectX 9–11 games."),
        WinetricksVerb(
            verb: "d3dx9", title: "DirectX 9 Runtime",
            detail: "Helps older DirectX 9 games launch."),
    ]
}

protocol BottleToolRunning: Sendable {
    /// Path to the `winetricks` binary, or `nil` if it is not installed.
    var winetricksPath: String? { get }

    /// Opens the Wine configuration panel (`winecfg`) for the bottle.
    func openConfiguration(bottle: Bottle, winePath: String) throws

    /// Initializes the prefix (`wineboot --init`) and waits for completion.
    func initializePrefix(bottle: Bottle, winePath: String) async throws

    /// Runs an arbitrary installer/executable inside the bottle. `onExit` fires
    /// (off the main thread) with the process status when the installer quits, so
    /// callers can auto-scan the prefix for what it installed. Returns the
    /// launched process so the caller can keep it alive until it exits.
    @discardableResult
    func runInstaller(
        at url: URL,
        bottle: Bottle,
        winePath: String,
        onExit: @escaping @Sendable (Int32) -> Void
    ) throws -> Process

    /// Launches a program inside Terminal.app so a console (CUI) tool's output
    /// is visible and interactive.
    func runInTerminal(program: WindowsProgram, bottle: Bottle, winePath: String) throws

    /// Installs a winetricks verb into the bottle, surfacing it in Terminal so
    /// the user can answer interactive prompts.
    func installDependency(_ verb: WinetricksVerb, bottle: Bottle, winePath: String) throws

    /// winetricks verbs already applied to the bottle, read from its
    /// `winetricks.log`. Empty if none/unknown.
    func installedVerbs(bottle: Bottle) -> Set<String>

    /// Hard-kills every Wine process in the bottle's prefix (`wineserver -k`).
    /// Best-effort and synchronous; used to tear a bottle down on quit/stop.
    func terminatePrefix(bottle: Bottle, winePath: String)
}

enum BottleToolError: LocalizedError {
    case winetricksMissing
    case helperMissing(String)

    var errorDescription: String? {
        switch self {
        case .winetricksMissing:
            "winetricks is not installed. Install it with: brew install winetricks"
        case let .helperMissing(name):
            "Could not find the \(name) helper next to your Wine binary."
        }
    }
}

struct BottleTooling: BottleToolRunning {
    private var fileManager: FileManager { .default }

    var winetricksPath: String? {
        ["/opt/homebrew/bin/winetricks", "/usr/local/bin/winetricks"]
            .first(where: fileManager.isExecutableFile(atPath:))
    }

    func openConfiguration(bottle: Bottle, winePath: String) throws {
        let prefixURL = try BottleStorage.prefixURL(for: bottle, using: fileManager)
        let process = Process()
        process.executableURL = URL(filePath: winePath)
        process.arguments = ["winecfg"]
        process.environment = environment(prefixURL: prefixURL, winePath: winePath)
        try process.run()
    }

    func initializePrefix(bottle: Bottle, winePath: String) async throws {
        let prefixURL = try BottleStorage.prefixURL(for: bottle, using: fileManager)
        let env = environment(prefixURL: prefixURL, winePath: winePath)
        await Task.detached(priority: .userInitiated) {
            _ = Shell.run(winePath, ["wineboot", "--init"], environment: env, timeout: 180)
        }.value
    }

    @discardableResult
    func runInstaller(
        at url: URL,
        bottle: Bottle,
        winePath: String,
        onExit: @escaping @Sendable (Int32) -> Void
    ) throws -> Process {
        let prefixURL = try BottleStorage.prefixURL(for: bottle, using: fileManager)
        let process = Process()
        process.executableURL = URL(filePath: winePath)
        process.arguments = Self.installerArguments(for: url)
        process.currentDirectoryURL = url.deletingLastPathComponent()
        process.environment = environment(prefixURL: prefixURL, winePath: winePath)
        process.terminationHandler = { finished in
            onExit(finished.terminationStatus)
        }
        try process.run()
        return process
    }

    static func installerArguments(for url: URL) -> [String] {
        url.pathExtension.lowercased() == "msi"
            ? ["msiexec", "/i", url.path]
            : [url.path]
    }

    func installDependency(_ verb: WinetricksVerb, bottle: Bottle, winePath: String) throws {
        guard let winetricksPath else { throw BottleToolError.winetricksMissing }
        let prefixURL = try BottleStorage.prefixURL(for: bottle, using: fileManager)

        // winetricks is interactive (EULAs, download prompts), so run it in a
        // Terminal window the same way the Wine installer flow does.
        let env = environment(prefixURL: prefixURL, winePath: winePath)
        let scriptURL = fileManager.temporaryDirectory
            .appending(path: "BottleLite-winetricks-\(verb.verb)-\(UUID().uuidString).command")

        let exports =
            env
            .map { "export \(shellEscaped($0.key))=\(shellEscaped($0.value))" }
            .joined(separator: "\n")

        let script = """
            #!/bin/zsh
            clear
            echo "BottleLite — installing \(verb.title) into \(bottle.name)"
            echo
            \(exports)
            \(shellEscaped(winetricksPath)) --unattended \(shellEscaped(verb.verb))
            status=$?
            echo
            if [ "$status" -eq 0 ]; then
              echo "\(verb.title) installed. You can close this window."
            else
              echo "winetricks exited with code $status."
            fi
            read -n 1 -s -r -p "Press any key to close this window..."
            """

        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: scriptURL.path)

        let open = Process()
        open.executableURL = URL(filePath: "/usr/bin/open")
        open.arguments = [scriptURL.path]
        try open.run()
    }

    func installedVerbs(bottle: Bottle) -> Set<String> {
        guard
            let prefixURL = try? BottleStorage.prefixURL(for: bottle, using: fileManager, create: false),
            let log = try? String(
                contentsOf: prefixURL.appending(path: "winetricks.log"), encoding: .utf8)
        else { return [] }

        let verbs =
            log
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return Set(verbs)
    }

    func runInTerminal(program: WindowsProgram, bottle: Bottle, winePath: String) throws {
        let prefixURL = try BottleStorage.prefixURL(for: bottle, using: fileManager)
        let env = environment(prefixURL: prefixURL, winePath: winePath)
        let workingDir = WineProgramRunner.workingDirectory(for: URL(filePath: program.path))
        let arguments = WineProgramRunner.parseArguments(program.arguments)

        let exports =
            env
            .map { "export \(shellEscaped($0.key))=\(shellEscaped($0.value))" }
            .joined(separator: "\n")
        let command = ([winePath, program.path] + arguments).map(shellEscaped).joined(separator: " ")

        let scriptURL = fileManager.temporaryDirectory
            .appending(path: "BottleLite-run-\(program.id.uuidString).command")

        let script = """
            #!/bin/zsh
            clear
            echo "BottleLite — running \(program.name) in \(bottle.name)"
            echo
            \(exports)
            cd \(shellEscaped(workingDir.path))
            \(command)
            status=$?
            echo
            echo "\(program.name) exited with code $status."
            read -n 1 -s -r -p "Press any key to close this window..."
            """

        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: scriptURL.path)

        let open = Process()
        open.executableURL = URL(filePath: "/usr/bin/open")
        open.arguments = [scriptURL.path]
        try open.run()
    }

    func terminatePrefix(bottle: Bottle, winePath: String) {
        guard let prefixURL = try? BottleStorage.prefixURL(for: bottle, using: fileManager) else { return }
        let env = environment(prefixURL: prefixURL, winePath: winePath)
        let wineBin = URL(filePath: winePath).deletingLastPathComponent()
        let wineserver = wineBin.appending(path: "wineserver").path

        if fileManager.isExecutableFile(atPath: wineserver) {
            Shell.run(wineserver, ["-k"], environment: env, timeout: 8)
        } else {
            // Fall back to launching wineserver via the wine loader.
            Shell.run(winePath, ["wineserver", "-k"], environment: env, timeout: 8)
        }
    }

    private func environment(prefixURL: URL, winePath: String) -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        environment["WINEPREFIX"] = prefixURL.path
        environment["WINEDEBUG"] = "-all"
        // Keep installers/winecfg from littering the Desktop with .desktop/.lnk
        // launchers; BottleLite generates native .app launchers instead.
        environment["WINEDLLOVERRIDES"] = "winemenubuilder.exe=d"
        let wineBin = URL(filePath: winePath).deletingLastPathComponent().path
        if let existingPath = environment["PATH"], !existingPath.isEmpty {
            environment["PATH"] = "\(wineBin):\(existingPath)"
        } else {
            environment["PATH"] = wineBin
        }
        return environment
    }
}

private func shellEscaped(_ value: String) -> String {
    "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
}
