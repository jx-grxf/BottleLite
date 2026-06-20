import Foundation
import Testing

@testable import BottleLite

struct DiagnosticReportTests {
    @Test func populatedReportContainsKeyValuesAndLogs() {
        let report = DiagnosticReport.format(
            DiagnosticInfo(
                appVersion: "1.2.3",
                macOSVersion: "Version 15.5",
                macModel: "Mac16,1",
                cpuArchitecture: "Apple Silicon (arm64)",
                wineVersion: "Wine 10.0",
                winetricksInstalled: true,
                bottleName: "Demo Bottle",
                gameMode: true,
                programName: "Demo.exe",
                programPath: "/Games/Demo.exe",
                lastLogLines: ["first log line", "second log line", "third log line"]
            )
        )

        #expect(report.contains("## BottleLite Diagnostic Report"))
        #expect(report.contains("App version: 1.2.3"))
        #expect(report.contains("macOS: Version 15.5"))
        #expect(report.contains("Wine version: Wine 10.0"))
        #expect(report.contains("first log line"))
        #expect(report.contains("second log line"))
        #expect(report.contains("third log line"))
    }

    @Test func reportHandlesMissingOptionalValues() {
        let report = DiagnosticReport.format(
            DiagnosticInfo(
                appVersion: "1.2.3",
                macOSVersion: "Version 15.5",
                macModel: "Mac16,1",
                cpuArchitecture: "Apple Silicon (arm64)",
                wineVersion: nil,
                winetricksInstalled: false,
                bottleName: nil,
                gameMode: nil,
                programName: nil,
                programPath: nil,
                lastLogLines: []
            )
        )

        #expect(report.contains("## BottleLite Diagnostic Report"))
        #expect(report.contains("not detected"))
        #expect(!report.contains("Program path:"))
    }

    @Test func tailLinesReturnsLastLinesAndMissingPathIsEmpty() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let logFile = directory.appending(path: "test.log")
        let contents = (1...10).map { "line \($0)" }.joined(separator: "\n")
        try contents.write(to: logFile, atomically: true, encoding: .utf8)

        #expect(DiagnosticReport.tailLines(ofFileAt: logFile, limit: 3) == ["line 8", "line 9", "line 10"])
        #expect(
            DiagnosticReport.tailLines(ofFileAt: directory.appending(path: "missing.log"), limit: 3) == [])
    }
}
