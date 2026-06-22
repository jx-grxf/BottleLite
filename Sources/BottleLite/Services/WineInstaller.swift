import Foundation

protocol WineInstalling: Sendable {
    func openInstaller() async throws
}

enum WineInstallError: LocalizedError {
    case homebrewMissing
    case terminalOpenFailed

    var errorDescription: String? {
        switch self {
        case .homebrewMissing:
            "Homebrew is not installed."
        case .terminalOpenFailed:
            "Could not open Terminal."
        }
    }
}

struct HomebrewWineInstaller: WineInstalling, Sendable {
    func openInstaller() async throws {
        try await HomebrewInstall.openInTerminal(
            title: "BottleLite Wine installer",
            note: "This may ask for your macOS password because Wine depends on system packages.",
            // --force so it installs even when Game Porting Toolkit already owns the
            // shared wine64/wineserver brew symlinks. BottleLite finds each Wine by
            // its .app bundle path, so the two coexist and GPTK keeps working.
            brewCommand: "install --cask --force wine-stable",
            doneNote: "Wine install finished. Go back to BottleLite and click Check Again."
        )
    }
}

protocol WinetricksInstalling: Sendable {
    func openInstaller() async throws
}

struct HomebrewWinetricksInstaller: WinetricksInstalling, Sendable {
    func openInstaller() async throws {
        try await HomebrewInstall.openInTerminal(
            title: "BottleLite winetricks installer",
            note: "winetricks installs common Windows components (fonts, runtimes, DirectX) into a bottle.",
            brewCommand: "install winetricks",
            doneNote: "winetricks installed. Go back to BottleLite and try the dependency again."
        )
    }
}

protocol GamingRuntimeInstalling: Sendable {
    func openInstaller() async throws
}

/// Installs MoltenVK (+ the Vulkan loader) so the DXVK backend can translate
/// DirectX → Vulkan → Metal. Both are permissively licensed.
struct HomebrewGamingRuntimeInstaller: GamingRuntimeInstalling {
    func openInstaller() async throws {
        try await HomebrewInstall.openInTerminal(
            title: "BottleLite gaming runtime",
            note: "Installs MoltenVK + the Vulkan loader so DXVK can run DirectX 9–11 games on Metal.",
            brewCommand: "install molten-vk vulkan-loader",
            doneNote: "Gaming runtime installed. Set a bottle's Graphics to DXVK and relaunch the game."
        )
    }
}

protocol GamePortingToolkitInstalling: Sendable {
    func openInstaller() async throws
}

/// Installs Gcenx's prebuilt Game Porting Toolkit (a CrossOver-lineage Wine +
/// D3DMetal). Unlike Apple's source-built tap, this is a ready-made app bundle,
/// so it installs in minutes and gives the Wine build that actually runs the
/// modern Steam client and DirectX 12 games. Needs Rosetta on Apple Silicon.
struct HomebrewGPTKInstaller: GamePortingToolkitInstalling {
    func openInstaller() async throws {
        try await HomebrewInstall.openInTerminal(
            title: "BottleLite — gaming-grade Wine (Game Porting Toolkit)",
            note:
                "Installs a CrossOver-lineage Wine + Apple's D3DMetal. This is what runs the "
                + "modern Steam client and DirectX 12 games. Large download; may install Rosetta "
                + "and ask to replace plain Wine.",
            brewCommands: [
                "tap gcenx/wine",
                // GPTK conflicts with plain wine-stable; remove it first (no-op
                // if absent). GPTK supersedes it as the bottle's Wine.
                "uninstall --cask wine-stable || true",
                "install --cask game-porting-toolkit",
            ],
            doneNote:
                "Gaming-grade Wine installed. Reopen BottleLite — it will use it automatically; "
                + "relaunch Steam or your game."
        )
    }
}

/// Shared helper that runs a `brew` command in a Terminal window so the user can
/// answer Homebrew's interactive prompts (EULAs, sudo password).
private enum HomebrewInstall {
    static func openInTerminal(
        title: String,
        note: String,
        brewCommand: String,
        doneNote: String
    ) async throws {
        try await openInTerminal(
            title: title, note: note, brewCommands: [brewCommand], doneNote: doneNote)
    }

    static func openInTerminal(
        title: String,
        note: String,
        brewCommands: [String],
        doneNote: String
    ) async throws {
        try await Task.detached(priority: .userInitiated) {
            let brewPath = [
                "/opt/homebrew/bin/brew",
                "/usr/local/bin/brew",
            ].first { FileManager.default.isExecutableFile(atPath: $0) }

            guard let brewPath else {
                throw WineInstallError.homebrewMissing
            }

            let scriptURL = FileManager.default.temporaryDirectory
                .appending(path: "BottleLite-Installer-\(UUID().uuidString).command")

            let commands =
                brewCommands
                .map { "\(shellEscaped(brewPath)) \($0)" }
                .joined(separator: " && \\\n")

            let script = """
                #!/bin/zsh
                clear
                echo "\(title)"
                echo "Type y if Homebrew asks to proceed."
                echo "\(note)"
                echo
                \(commands)
                rc=$?
                echo
                if [ "$rc" -eq 0 ]; then
                  echo "\(doneNote)"
                else
                  echo "Install failed with exit code $rc."
                fi
                echo
                read -n 1 -s -r -p "Press any key to close this window..."
                """

            try script.write(to: scriptURL, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o700],
                ofItemAtPath: scriptURL.path
            )

            let process = Process()
            process.executableURL = URL(filePath: "/usr/bin/open")
            process.arguments = [scriptURL.path]

            try process.run()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else {
                throw WineInstallError.terminalOpenFailed
            }
        }.value
    }
}

private func shellEscaped(_ value: String) -> String {
    "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
}
