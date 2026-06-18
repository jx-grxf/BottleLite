import Foundation

protocol ProgramRunning {
    @discardableResult
    func launch(
        program: WindowsProgram,
        bottle: Bottle,
        winePath: String,
        terminationHandler: @escaping @Sendable (ProgramTermination) -> Void
    ) throws -> ProgramLaunch

    func stop(_ launch: ProgramLaunch) throws
}

struct ProgramLaunch: Equatable {
    let processID: Int32
}

struct ProgramTermination: Equatable, Sendable {
    let status: Int32

    func message(for programName: String) -> String {
        status == 0
            ? "\(programName) finished."
            : "\(programName) exited with code \(status)."
    }
}

struct WineProgramRunner: ProgramRunning {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    @discardableResult
    func launch(
        program: WindowsProgram,
        bottle: Bottle,
        winePath: String,
        terminationHandler: @escaping @Sendable (ProgramTermination) -> Void
    ) throws -> ProgramLaunch {
        let prefixURL = try ensurePrefixDirectory(for: bottle)
        let executableURL = URL(filePath: program.path)

        let process = Process()
        process.executableURL = URL(filePath: winePath)
        process.arguments = [program.path]
        process.currentDirectoryURL = executableURL.deletingLastPathComponent()
        process.environment = launchEnvironment(prefixURL: prefixURL)
        process.terminationHandler = { process in
            terminationHandler(ProgramTermination(status: process.terminationStatus))
        }

        try process.run()
        return ProgramLaunch(processID: process.processIdentifier)
    }

    func stop(_ launch: ProgramLaunch) throws {
        let process = Process()
        process.executableURL = URL(filePath: "/bin/kill")
        process.arguments = ["-TERM", "\(launch.processID)"]
        try process.run()
    }

    private func ensurePrefixDirectory(for bottle: Bottle) throws -> URL {
        let baseURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        .appending(path: "BottleLite", directoryHint: .isDirectory)
        .appending(path: "Bottles", directoryHint: .isDirectory)
        .appending(path: bottle.id.uuidString, directoryHint: .isDirectory)

        try fileManager.createDirectory(at: baseURL, withIntermediateDirectories: true)
        return baseURL
    }

    private func launchEnvironment(prefixURL: URL) -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        environment["WINEPREFIX"] = prefixURL.path
        environment["WINEDEBUG"] = "-all"
        return environment
    }
}
