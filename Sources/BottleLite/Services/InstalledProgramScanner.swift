import Foundation

/// An executable discovered inside a bottle's Wine prefix (the result of running
/// an installer), offered to the user as a program they can add and launch.
struct FoundExecutable: Identifiable, Hashable {
    let url: URL
    let displayPath: String

    var id: String { url.path }
    var name: String { url.deletingPathExtension().lastPathComponent }
}

/// Scans a bottle's virtual C: drive for installed game/app executables so the
/// user does not have to hunt through `drive_c` by hand after an installer runs.
enum InstalledProgramScanner {
    /// Filename fragments that mark an executable as plumbing rather than the app
    /// itself (uninstallers, redistributables, crash handlers, …).
    static let excludedFragments = [
        "unins", "uninst", "setup", "install", "vcredist", "vc_redist", "dxsetup",
        "dotnet", "redist", "crashpad", "crashhandler", "crashreport", "report",
        "helper", "update", "patch", "config", "settings", "register",
    ]

    /// Top-level `drive_c` folders that never contain a user-facing game.
    static let skippedTopLevel: Set<String> = [
        "windows", "users", "programdata", "$recycle.bin", "system volume information",
    ]

    static func scan(
        bottle: Bottle, fileManager: FileManager = .default, limit: Int = 250
    ) -> [FoundExecutable] {
        guard let driveC = try? BottleStorage.driveCURL(for: bottle, using: fileManager, create: false)
        else { return [] }
        return scan(driveC: driveC, fileManager: fileManager, limit: limit)
    }

    static func scan(
        driveC: URL,
        fileManager: FileManager = .default,
        limit: Int = 250,
        maxDepth: Int = 6
    ) -> [FoundExecutable] {
        guard fileManager.fileExists(atPath: driveC.path) else { return [] }

        var found: [FoundExecutable] = []
        var seen = Set<String>()

        for root in rootDirectories(in: driveC, fileManager: fileManager) {
            let rootDepth = root.pathComponents.count
            let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            )

            while let item = enumerator?.nextObject() as? URL {
                if found.count >= limit { break }
                if item.pathComponents.count - rootDepth > maxDepth {
                    enumerator?.skipDescendants()
                    continue
                }
                guard item.pathExtension.lowercased() == "exe" else { continue }

                let lower = item.lastPathComponent.lowercased()
                if excludedFragments.contains(where: lower.contains) { continue }
                guard seen.insert(item.path).inserted else { continue }

                let relative = item.path.replacingOccurrences(of: driveC.path + "/", with: "C:/")
                found.append(FoundExecutable(url: item, displayPath: relative))
            }
        }

        return found.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// `Program Files` variants plus any other non-system top-level folder, so
    /// games installed to `C:\Games` or their own root folder are also found.
    private static func rootDirectories(in driveC: URL, fileManager: FileManager) -> [URL] {
        var roots: [URL] = []
        var seen = Set<String>()

        func add(_ url: URL) {
            guard fileManager.fileExists(atPath: url.path), seen.insert(url.path).inserted else { return }
            roots.append(url)
        }

        add(driveC.appending(path: "Program Files"))
        add(driveC.appending(path: "Program Files (x86)"))

        let contents =
            (try? fileManager.contentsOfDirectory(
                at: driveC,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )) ?? []

        for entry in contents {
            let isDir = (try? entry.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            guard isDir, !skippedTopLevel.contains(entry.lastPathComponent.lowercased()) else { continue }
            add(entry)
        }

        return roots
    }
}
