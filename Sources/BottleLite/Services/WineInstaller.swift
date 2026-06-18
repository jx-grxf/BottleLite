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
        try await Task.detached(priority: .userInitiated) {
            let brewPath = [
                "/opt/homebrew/bin/brew",
                "/usr/local/bin/brew"
            ].first { FileManager.default.isExecutableFile(atPath: $0) }

            guard let brewPath else {
                throw WineInstallError.homebrewMissing
            }

            let command = """
            clear
            echo "BottleLite Wine installer"
            echo "This may ask for your macOS password because Wine depends on system packages."
            echo
            \(shellEscaped(brewPath)) install --cask wine-stable
            status=$?
            echo
            if [ "$status" -eq 0 ]; then
              echo "Wine install finished. Go back to BottleLite and click Check Again."
            else
              echo "Wine install failed with exit code $status."
            fi
            echo
            read -n 1 -s -r -p "Press any key to close this window..."
            """

            let process = Process()
            process.executableURL = URL(filePath: "/usr/bin/osascript")
            process.arguments = [
                "-e",
                """
                tell application "Terminal"
                  activate
                  do script \(appleScriptQuoted(command))
                end tell
                """
            ]

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

private func appleScriptQuoted(_ value: String) -> String {
    let escaped = value
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
        .replacingOccurrences(of: "\n", with: "\\n")
    return "\"\(escaped)\""
}
