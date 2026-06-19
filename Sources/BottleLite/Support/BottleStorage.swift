import Foundation

/// Centralizes the on-disk layout BottleLite uses under Application Support so
/// the runner, repository, and tooling agree on where prefixes and logs live.
///
/// ```
/// ~/Library/Application Support/BottleLite/
///   bottles.json                 persisted bottle records
///   Bottles/<bottle-uuid>/        a Wine prefix (WINEPREFIX)
///     drive_c/                    the virtual C: drive (created by Wine)
///     Logs/<program-uuid>.log     captured stdout/stderr per launch
/// ```
enum BottleStorage {
    static let directoryName = "BottleLite"
    static let bottlesFileName = "bottles.json"

    static func supportDirectory(using fileManager: FileManager = .default) throws -> URL {
        let base = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = base.appending(path: directoryName, directoryHint: .isDirectory)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static func bottlesFileURL(using fileManager: FileManager = .default) throws -> URL {
        try supportDirectory(using: fileManager).appending(path: bottlesFileName)
    }

    static func bottlesDirectory(using fileManager: FileManager = .default) throws -> URL {
        let directory = try supportDirectory(using: fileManager)
            .appending(path: "Bottles", directoryHint: .isDirectory)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    /// The Wine prefix directory for a bottle, creating intermediate folders.
    static func prefixURL(for bottle: Bottle, using fileManager: FileManager = .default) throws -> URL {
        let prefix = try bottlesDirectory(using: fileManager)
            .appending(path: bottle.id.uuidString, directoryHint: .isDirectory)
        try fileManager.createDirectory(at: prefix, withIntermediateDirectories: true)
        return prefix
    }

    static func driveCURL(for bottle: Bottle, using fileManager: FileManager = .default) throws -> URL {
        try prefixURL(for: bottle, using: fileManager)
            .appending(path: "drive_c", directoryHint: .isDirectory)
    }

    static func logsDirectory(for bottle: Bottle, using fileManager: FileManager = .default) throws -> URL {
        let logs = try prefixURL(for: bottle, using: fileManager)
            .appending(path: "Logs", directoryHint: .isDirectory)
        try fileManager.createDirectory(at: logs, withIntermediateDirectories: true)
        return logs
    }

    static func logURL(
        for program: WindowsProgram,
        in bottle: Bottle,
        using fileManager: FileManager = .default
    ) throws -> URL {
        try logsDirectory(for: bottle, using: fileManager)
            .appending(path: "\(program.id.uuidString).log")
    }

    /// Whether a bottle's prefix has already been initialized by Wine. A fresh
    /// prefix gains `system.reg` once `wineboot` (or the first launch) runs.
    static func isPrefixInitialized(for bottle: Bottle, using fileManager: FileManager = .default) -> Bool {
        guard let prefix = try? prefixURL(for: bottle, using: fileManager) else { return false }
        return fileManager.fileExists(atPath: prefix.appending(path: "system.reg").path)
    }
}
