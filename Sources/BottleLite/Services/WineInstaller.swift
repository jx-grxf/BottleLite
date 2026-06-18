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

            let scriptURL = FileManager.default.temporaryDirectory
                .appending(path: "BottleLite-Wine-Installer-\(UUID().uuidString).command")

            let script = """
            #!/bin/zsh
            clear
            echo "BottleLite Wine installer"
            echo "Type y if Homebrew asks to proceed."
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
