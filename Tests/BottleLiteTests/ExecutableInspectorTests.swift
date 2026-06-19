import Foundation
import Testing

@testable import BottleLite

struct ExecutableInspectorTests {
    @Test func acceptsMZExecutable() throws {
        let url = try temporaryFile(named: "demo.exe", bytes: [0x4D, 0x5A, 0x90, 0x00])
        #expect(ExecutableInspector.validate(url) == .valid)
    }

    @Test func rejectsWrongExtension() throws {
        let url = try temporaryFile(named: "demo.txt", bytes: [0x4D, 0x5A])
        #expect(ExecutableInspector.validate(url) == .wrongExtension)
    }

    @Test func rejectsMissingMagic() throws {
        let url = try temporaryFile(named: "demo.exe", bytes: [0x00, 0x00])
        #expect(ExecutableInspector.validate(url) == .missingMagic)
    }

    @Test func detectsConsoleSubsystem() {
        #expect(ExecutableInspector.subsystem(parsing: peBytes(subsystem: 3)) == .console)
    }

    @Test func detectsGuiSubsystem() {
        #expect(ExecutableInspector.subsystem(parsing: peBytes(subsystem: 2)) == .gui)
    }

    @Test func returnsUnknownForIncompletePEHeader() {
        #expect(ExecutableInspector.subsystem(parsing: [0x4D, 0x5A]) == .unknown)
    }

    private func temporaryFile(named name: String, bytes: [UInt8]) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let url = directory.appendingPathComponent(name)
        try Data(bytes).write(to: url)
        return url
    }

    private func peBytes(subsystem: UInt16) -> [UInt8] {
        let peOffset = 0x80
        let subsystemOffset = peOffset + 24 + 68
        var bytes = [UInt8](repeating: 0, count: subsystemOffset + 2)

        bytes[0] = 0x4D
        bytes[1] = 0x5A
        bytes[0x3C] = UInt8(peOffset & 0xFF)
        bytes[0x3D] = UInt8((peOffset >> 8) & 0xFF)
        bytes[peOffset] = 0x50
        bytes[peOffset + 1] = 0x45
        bytes[subsystemOffset] = UInt8(subsystem & 0xFF)
        bytes[subsystemOffset + 1] = UInt8((subsystem >> 8) & 0xFF)

        return bytes
    }
}
