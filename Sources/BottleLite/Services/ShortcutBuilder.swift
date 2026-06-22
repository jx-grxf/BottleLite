import AppKit
import Foundation

/// Where a generated launcher should be placed.
enum ShortcutDestination {
    case desktop
    case applications

    var directoryName: String {
        switch self {
        case .desktop: "Desktop"
        case .applications: "Applications"
        }
    }
}

enum ShortcutError: LocalizedError {
    case executableMissing
    case directoryUnavailable

    var errorDescription: String? {
        switch self {
        case .executableMissing:
            "The program's executable could not be found on disk anymore."
        case .directoryUnavailable:
            "Could not locate the destination folder."
        }
    }
}

/// Builds native macOS `.app` launchers for Windows programs so they get a real,
/// clickable icon in Finder/Applications instead of the raw `.desktop`/`.lnk`
/// files Wine's `winemenubuilder` drops onto the Desktop. Each launcher is a tiny
/// bundle whose executable is a shell script that runs the program through Wine
/// in the correct bottle prefix.
enum ShortcutBuilder {
    @discardableResult
    static func createLauncher(
        for program: WindowsProgram,
        in bottle: Bottle,
        winePath: String,
        destination: ShortcutDestination,
        fileManager: FileManager = .default
    ) throws -> URL {
        guard fileManager.fileExists(atPath: program.path) else {
            throw ShortcutError.executableMissing
        }

        let prefixURL = try BottleStorage.prefixURL(for: bottle, using: fileManager)
        let directory = try destinationDirectory(destination, fileManager: fileManager)
        let appName = sanitizedAppName(program.name)
        let appURL = uniqueURL(in: directory, name: appName, fileManager: fileManager)

        let contents = appURL.appending(path: "Contents")
        let macos = contents.appending(path: "MacOS")
        try fileManager.createDirectory(at: macos, withIntermediateDirectories: true)

        let scriptURL = macos.appending(path: "launch")
        let script = launchScript(
            program: program, bottle: bottle, prefixPath: prefixURL.path, winePath: winePath)
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

        let plist = infoPlist(appName: appName)
        try plist.write(to: contents.appending(path: "Info.plist"), atomically: true, encoding: .utf8)

        // Real Windows icon when we can extract it; Finder falls back to the
        // generic app icon otherwise. setIcon stores a custom Finder icon, so no
        // bundled .icns is required.
        if let icon = ExecutableIconExtractor.icon(forExecutableAt: URL(filePath: program.path)) {
            NSWorkspace.shared.setIcon(icon, forFile: appURL.path, options: [])
        }

        return appURL
    }

    /// Removes the Linux-style `.desktop` launchers Wine drops on the Desktop for
    /// our bottles. Only files whose `Exec=` references a BottleLite prefix are
    /// touched, so unrelated Desktop files are never deleted. Returns how many
    /// were moved to the Trash.
    @discardableResult
    static func cleanWineDesktopClutter(fileManager: FileManager = .default) -> Int {
        guard
            let desktop = try? fileManager.url(
                for: .desktopDirectory, in: .userDomainMask, appropriateFor: nil, create: false),
            let support = try? BottleStorage.supportDirectory(using: fileManager),
            let entries = try? fileManager.contentsOfDirectory(
                at: desktop, includingPropertiesForKeys: nil)
        else { return 0 }

        var removed = 0
        for entry in entries where entry.pathExtension == "desktop" {
            guard
                let contents = try? String(contentsOf: entry, encoding: .utf8),
                contents.contains(support.path)
            else { continue }
            if (try? fileManager.trashItem(at: entry, resultingItemURL: nil)) != nil {
                removed += 1
            }
        }
        return removed
    }

    // MARK: - Pure helpers (exposed for testing)

    /// The shell script that becomes the bundle's executable. Uses the exact same
    /// environment (graphics-backend DLL overrides, Game Mode, library paths) and
    /// injected arguments as the in-app runner, so a program launched from its
    /// `.app` shortcut behaves identically to launching it inside BottleLite.
    static func launchScript(
        program: WindowsProgram, bottle: Bottle, prefixPath: String, winePath: String
    ) -> String {
        let wineBin = URL(filePath: winePath).deletingLastPathComponent().path
        let executableURL = URL(filePath: program.path)
        let workingDir = WineProgramRunner.workingDirectory(for: executableURL).path
        let arguments =
            WineProgramRunner.parseArguments(program.arguments)
            + WineProgramRunner.injectedArguments(
                forExecutableAt: executableURL, userArguments: program.arguments)
        let command = ([winePath, program.path] + arguments).map(shellEscaped).joined(separator: " ")

        let env = WineProgramRunner.wineEnvironment(
            prefixPath: prefixPath, winePath: winePath, gameMode: bottle.gameMode,
            graphicsBackend: bottle.graphicsBackend)
        let exports =
            env.sorted { $0.key < $1.key }
            .map { "export \($0.key)=\(shellEscaped($0.value))" }
            .joined(separator: "\n")

        return """
            #!/bin/zsh
            \(exports)
            export PATH=\(shellEscaped(wineBin)):$PATH
            cd \(shellEscaped(workingDir))
            exec \(command)
            """
    }

    /// A Finder-safe bundle name (no path separators, never empty).
    static func sanitizedAppName(_ raw: String) -> String {
        let cleaned =
            raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        return cleaned.isEmpty ? "Windows App" : cleaned
    }

    // MARK: - Private

    private static func destinationDirectory(
        _ destination: ShortcutDestination,
        fileManager: FileManager
    ) throws -> URL {
        switch destination {
        case .desktop:
            guard
                let desktop = try? fileManager.url(
                    for: .desktopDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            else { throw ShortcutError.directoryUnavailable }
            return desktop
        case .applications:
            guard
                let apps = try? fileManager.url(
                    for: .applicationDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            else { throw ShortcutError.directoryUnavailable }
            let folder = apps.appending(path: "BottleLite", directoryHint: .isDirectory)
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
            return folder
        }
    }

    private static func uniqueURL(in directory: URL, name: String, fileManager: FileManager) -> URL {
        let base = directory.appending(path: "\(name).app")
        guard fileManager.fileExists(atPath: base.path) else { return base }
        var index = 2
        while true {
            let candidate = directory.appending(path: "\(name) \(index).app")
            if !fileManager.fileExists(atPath: candidate.path) { return candidate }
            index += 1
        }
    }

    private static func infoPlist(appName: String) -> String {
        let bundleID =
            "dev.johannesgrof.BottleLite.shortcut."
            + (appName.lowercased().filter { $0.isLetter || $0.isNumber }.isEmpty
                ? "app" : appName.lowercased().filter { $0.isLetter || $0.isNumber })
        return """
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0">
            <dict>
              <key>CFBundleExecutable</key>
              <string>launch</string>
              <key>CFBundleIdentifier</key>
              <string>\(bundleID)</string>
              <key>CFBundleName</key>
              <string>\(appName)</string>
              <key>CFBundlePackageType</key>
              <string>APPL</string>
              <key>LSMinimumSystemVersion</key>
              <string>14.0</string>
              <key>LSApplicationCategoryType</key>
              <string>public.app-category.games</string>
            </dict>
            </plist>
            """
    }

    private static func shellEscaped(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}
