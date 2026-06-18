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

    private func temporaryFile(named name: String, bytes: [UInt8]) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let url = directory.appendingPathComponent(name)
        try Data(bytes).write(to: url)
        return url
    }
}
