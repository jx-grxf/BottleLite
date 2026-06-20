import Foundation

enum SteamInstallerError: LocalizedError {
    case downloadFailed

    var errorDescription: String? {
        switch self {
        case .downloadFailed:
            "Could not download the Steam installer. Check your internet connection."
        }
    }
}

/// Downloads the official Steam installer so BottleLite can run it inside a
/// bottle. Steam itself is fetched at run time (never bundled).
enum SteamInstaller {
    /// Valve's stable public installer URL.
    static let setupURL = URL(string: "https://cdn.fastly.steamstatic.com/client/installer/SteamSetup.exe")!

    /// Downloads `SteamSetup.exe` to a temporary location and returns its URL.
    static func downloadSetup(session: URLSession = .shared) async throws -> URL {
        let (tempURL, response) = try await session.download(from: setupURL)

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw SteamInstallerError.downloadFailed
        }

        let destination = FileManager.default.temporaryDirectory
            .appending(path: "SteamSetup.exe")
        try? FileManager.default.removeItem(at: destination)
        do {
            try FileManager.default.moveItem(at: tempURL, to: destination)
        } catch {
            throw SteamInstallerError.downloadFailed
        }
        return destination
    }
}
