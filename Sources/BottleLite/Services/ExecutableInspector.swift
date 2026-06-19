import Foundation

/// The Windows subsystem an executable targets, which decides how BottleLite
/// should launch it: GUI apps run silently, console (CUI) tools need a terminal.
enum ProgramSubsystem: Equatable {
    case gui
    case console
    case unknown
}

enum ExecutableInspector {
    static func validate(_ url: URL) -> ExecutableValidation {
        guard url.pathExtension.lowercased() == "exe" else {
            return .wrongExtension
        }

        guard let handle = try? FileHandle(forReadingFrom: url) else {
            return .unreadable
        }

        defer {
            try? handle.close()
        }

        do {
            let data = try handle.read(upToCount: 2) ?? Data()
            return data == Data([0x4D, 0x5A]) ? .valid : .missingMagic
        } catch {
            return .unreadable
        }
    }

    /// Reads the PE optional-header Subsystem field to tell console tools from
    /// GUI apps. Returns `.unknown` for anything it cannot parse confidently.
    static func subsystem(of url: URL) -> ProgramSubsystem {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return .unknown }
        defer { try? handle.close() }
        guard let head = try? handle.read(upToCount: 4096), head.count >= 0x40 else { return .unknown }
        return subsystem(parsing: [UInt8](head))
    }

    /// Pure parser exposed for testing. `bytes` is the start of the file.
    static func subsystem(parsing bytes: [UInt8]) -> ProgramSubsystem {
        guard bytes.count >= 0x40, bytes[0] == 0x4D, bytes[1] == 0x5A else { return .unknown }

        let lfanew =
            Int(bytes[0x3C]) | Int(bytes[0x3D]) << 8 | Int(bytes[0x3E]) << 16 | Int(bytes[0x3F]) << 24
        // Subsystem sits at optional-header offset 68; the optional header
        // begins 24 bytes after the PE signature. Offset is identical for
        // PE32 and PE32+.
        let subsystemOffset = lfanew + 24 + 68
        guard lfanew >= 0, subsystemOffset + 1 < bytes.count else { return .unknown }
        guard bytes[lfanew] == 0x50, bytes[lfanew + 1] == 0x45,
            bytes[lfanew + 2] == 0, bytes[lfanew + 3] == 0
        else { return .unknown }

        let value = Int(bytes[subsystemOffset]) | Int(bytes[subsystemOffset + 1]) << 8
        switch value {
        case 2: return .gui
        case 3: return .console
        default: return .unknown
        }
    }
}
