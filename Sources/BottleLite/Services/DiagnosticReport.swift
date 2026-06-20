import Foundation

/// Inputs for a diagnostic report. Pure data so formatting is testable.
struct DiagnosticInfo: Equatable {
    var appVersion: String
    var macOSVersion: String
    var macModel: String
    var cpuArchitecture: String
    var wineVersion: String?
    var winetricksInstalled: Bool
    var bottleName: String?
    var gameMode: Bool?
    var programName: String?
    var programPath: String?
    var lastLogLines: [String]
}

enum DiagnosticReport {
    /// Deterministic, plain-text (Markdown) report. Pure function.
    static func format(_ info: DiagnosticInfo) -> String {
        var lines = [
            "## BottleLite Diagnostic Report",
            "",
            "- App version: \(info.appVersion)",
            "- macOS: \(info.macOSVersion)",
            "- Mac model: \(info.macModel)",
            "- CPU architecture: \(info.cpuArchitecture)",
            "- Wine version: \(info.wineVersion ?? "not detected")",
            "- winetricks: \(info.winetricksInstalled ? "Installed" : "Not installed")",
        ]

        if let bottleName = info.bottleName {
            lines.append("- Bottle: \(bottleName)")
        }

        if let gameMode = info.gameMode {
            lines.append("- Game Mode: \(gameMode ? "Enabled" : "Disabled")")
        }

        if let programName = info.programName {
            lines.append("- Program: \(programName)")
        }

        if let programPath = info.programPath {
            lines.append("- Program path: \(programPath)")
        }

        lines.append("")
        lines.append("### Last \(info.lastLogLines.count) log lines")
        lines.append("")
        lines.append("```")
        lines.append(contentsOf: info.lastLogLines)
        lines.append("```")

        return lines.joined(separator: "\n")
    }

    /// Live system facts gathered from the OS.
    static func systemInfo() -> (macOSVersion: String, macModel: String, cpuArchitecture: String) {
        (
            macOSVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            macModel: readSysctlString("hw.model") ?? "Unknown",
            cpuArchitecture: cpuArchitecture()
        )
    }

    /// Reads up to the last `limit` lines of a log file (returns [] if missing).
    static func tailLines(ofFileAt url: URL, limit: Int) -> [String] {
        guard limit > 0, let contents = try? String(contentsOf: url, encoding: .utf8) else {
            return []
        }

        let lines = contents.split(whereSeparator: \.isNewline).map(String.init)
        return Array(lines.suffix(limit))
    }

    private static func readSysctlString(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else {
            return nil
        }

        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0, buffer.contains(0) else {
            return nil
        }

        let endIndex = buffer.firstIndex(of: 0) ?? buffer.endIndex
        let bytes = buffer[..<endIndex].map { UInt8(bitPattern: $0) }
        let value = String(decoding: bytes, as: UTF8.self)
        return value.isEmpty ? nil : value
    }

    private static func cpuArchitecture() -> String {
        var systemInfo = utsname()
        guard uname(&systemInfo) == 0 else {
            return "Unknown"
        }

        let machine = withUnsafeBytes(of: &systemInfo.machine) { bytes in
            let identifier = bytes.prefix(while: { $0 != 0 })
            return String(decoding: identifier, as: UTF8.self)
        }

        switch machine {
        case "arm64":
            return "Apple Silicon (arm64)"
        case "x86_64":
            return "Intel (x86_64)"
        default:
            return machine.isEmpty ? "Unknown" : machine
        }
    }
}
