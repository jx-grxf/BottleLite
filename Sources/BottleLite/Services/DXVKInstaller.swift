import Foundation

enum DXVKInstallError: LocalizedError {
    case prefixNotReady
    case noRelease
    case downloadFailed
    case extractionFailed

    var errorDescription: String? {
        switch self {
        case .prefixNotReady:
            "Prepare the bottle first (run an app or use Prepare Bottle) so its Windows folders exist."
        case .noRelease:
            "Could not find a DXVK release to download."
        case .downloadFailed:
            "Downloading DXVK failed. Check your internet connection."
        case .extractionFailed:
            "Could not unpack the DXVK download."
        }
    }
}

/// Downloads the macOS DXVK build and installs its DLLs into a bottle's prefix
/// so the DXVK graphics backend has libraries to use. DXVK is MIT/zlib-licensed,
/// so fetching it at run time is fine. A marker file records that it's installed.
enum DXVKInstaller {
    /// macOS-tuned DXVK build (Direct3D → MoltenVK/Vulkan).
    private static let latestReleaseAPI = URL(
        string: "https://api.github.com/repos/Gcenx/DXVK-macOS/releases/latest")!
    private static let markerName = ".bottlelite-dxvk"

    static func isInstalled(inPrefix prefixURL: URL, fileManager: FileManager = .default) -> Bool {
        fileManager.fileExists(atPath: prefixURL.appending(path: markerName).path)
    }

    static func install(
        intoPrefix prefixURL: URL,
        session: URLSession = .shared,
        fileManager: FileManager = .default
    ) async throws {
        let system32 = prefixURL.appending(path: "drive_c/windows/system32")
        let syswow64 = prefixURL.appending(path: "drive_c/windows/syswow64")
        guard fileManager.fileExists(atPath: system32.path) else {
            throw DXVKInstallError.prefixNotReady
        }

        let asset = try await latestTarballURL(session: session)
        let (tempFile, response) = try await session.download(from: asset)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw DXVKInstallError.downloadFailed
        }

        let workDir = fileManager.temporaryDirectory
            .appending(path: "BottleLite-dxvk-\(UUID().uuidString)", directoryHint: .isDirectory)
        try fileManager.createDirectory(at: workDir, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: workDir) }

        let archive = workDir.appending(path: "dxvk.tar.gz")
        try fileManager.moveItem(at: tempFile, to: archive)
        try extract(archive: archive, into: workDir, fileManager: fileManager)

        guard let x64 = findDirectory(named: "x64", under: workDir, fileManager: fileManager) else {
            throw DXVKInstallError.extractionFailed
        }
        try copyDLLs(from: x64, to: system32, fileManager: fileManager)

        if let x32 = findDirectory(named: "x32", under: workDir, fileManager: fileManager),
            fileManager.fileExists(atPath: syswow64.path)
        {
            try copyDLLs(from: x32, to: syswow64, fileManager: fileManager)
        }

        try? Data().write(to: prefixURL.appending(path: markerName))
    }

    // MARK: - Private

    private static func latestTarballURL(session: URLSession) async throws -> URL {
        var request = URLRequest(url: latestReleaseAPI)
        request.setValue("BottleLite", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw DXVKInstallError.noRelease
        }

        let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
        guard let asset = release.assets.first(where: { $0.name.hasSuffix(".tar.gz") }) else {
            throw DXVKInstallError.noRelease
        }
        return asset.browserDownloadURL
    }

    private static func extract(archive: URL, into dir: URL, fileManager: FileManager) throws {
        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/tar")
        process.arguments = ["-xzf", archive.path, "-C", dir.path]
        do {
            try process.run()
        } catch {
            throw DXVKInstallError.extractionFailed
        }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw DXVKInstallError.extractionFailed
        }
    }

    private static func findDirectory(named name: String, under root: URL, fileManager: FileManager) -> URL? {
        guard
            let enumerator = fileManager.enumerator(
                at: root, includingPropertiesForKeys: [.isDirectoryKey])
        else { return nil }
        for case let url as URL in enumerator
        where url.lastPathComponent == name
            && (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
        {
            return url
        }
        return nil
    }

    private static func copyDLLs(from source: URL, to destination: URL, fileManager: FileManager) throws {
        let contents = try fileManager.contentsOfDirectory(at: source, includingPropertiesForKeys: nil)
        for dll in contents where dll.pathExtension.lowercased() == "dll" {
            let target = destination.appending(path: dll.lastPathComponent)
            try? fileManager.removeItem(at: target)
            try fileManager.copyItem(at: dll, to: target)
        }
    }
}

private struct GitHubRelease: Decodable {
    let assets: [Asset]

    struct Asset: Decodable {
        let name: String
        let browserDownloadURL: URL

        enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadURL = "browser_download_url"
        }
    }
}
