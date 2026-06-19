import Foundation

/// Small synchronous helper for running short-lived command line tools and
/// capturing their output. Intended for quick probes such as `wine --version`
/// where blocking briefly is acceptable. Long-running programs are launched
/// through `WineProgramRunner` instead.
enum Shell {
    struct Output: Equatable {
        var status: Int32
        var standardOutput: String
        var standardError: String

        var trimmedOutput: String {
            standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        var succeeded: Bool { status == 0 }
    }

    enum ShellError: Error {
        case timedOut
    }

    /// Runs `executable` with `arguments`, returning captured output.
    /// Returns `nil` if the process could not be launched at all.
    @discardableResult
    static func run(
        _ executable: String,
        _ arguments: [String] = [],
        environment: [String: String]? = nil,
        currentDirectory: URL? = nil,
        timeout: TimeInterval = 15
    ) -> Output? {
        let process = Process()
        process.executableURL = URL(filePath: executable)
        process.arguments = arguments
        if let environment {
            process.environment = environment
        }
        if let currentDirectory {
            process.currentDirectoryURL = currentDirectory
        }

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        // Drain pipes concurrently so a large amount of output cannot deadlock
        // the child against a full OS buffer while we wait for it to exit.
        let outputData = DataAccumulator()
        let errorData = DataAccumulator()
        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            outputData.append(handle.availableData)
        }
        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            errorData.append(handle.availableData)
        }

        do {
            try process.run()
        } catch {
            return nil
        }

        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline {
            usleep(20_000)
        }

        if process.isRunning {
            process.terminate()
        }
        process.waitUntilExit()

        outputPipe.fileHandleForReading.readabilityHandler = nil
        errorPipe.fileHandleForReading.readabilityHandler = nil
        outputData.append(outputPipe.fileHandleForReading.readDataToEndOfFile())
        errorData.append(errorPipe.fileHandleForReading.readDataToEndOfFile())

        return Output(
            status: process.terminationStatus,
            standardOutput: outputData.string,
            standardError: errorData.string
        )
    }
}

/// Thread-safe buffer for collecting piped output from a background readability
/// handler. Foundation invokes those handlers on an arbitrary queue.
private final class DataAccumulator: @unchecked Sendable {
    private var data = Data()
    private let lock = NSLock()

    func append(_ chunk: Data) {
        guard !chunk.isEmpty else { return }
        lock.lock()
        data.append(chunk)
        lock.unlock()
    }

    var string: String {
        lock.lock()
        defer { lock.unlock() }
        return String(decoding: data, as: UTF8.self)
    }
}
