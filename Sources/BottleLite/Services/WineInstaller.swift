import Foundation

protocol WineInstalling: Sendable {
    func installWine() async throws
}

enum WineInstallError: LocalizedError {
    case homebrewMissing
    case installationFailed(Int32)

    var errorDescription: String? {
        switch self {
        case .homebrewMissing:
            "Homebrew is not installed."
        case let .installationFailed(status):
            "Homebrew exited with code \(status)."
        }
    }
}

struct HomebrewWineInstaller: WineInstalling, Sendable {
    func installWine() async throws {
        try await Task.detached(priority: .userInitiated) {
            let brewPath = [
                "/opt/homebrew/bin/brew",
                "/usr/local/bin/brew"
            ].first { FileManager.default.isExecutableFile(atPath: $0) }

            guard let brewPath else {
                throw WineInstallError.homebrewMissing
            }

            let process = Process()
            process.executableURL = URL(filePath: brewPath)
            process.arguments = ["install", "--cask", "wine-stable"]

            try process.run()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else {
                throw WineInstallError.installationFailed(process.terminationStatus)
            }
        }.value
    }
}
