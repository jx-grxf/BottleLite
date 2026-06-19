import Foundation
import Testing

@testable import BottleLite

struct InstalledProgramScannerTests {
    @Test func findsGamesAndSkipsInstallersAndSystemFolders() throws {
        let fm = FileManager.default
        let driveC = fm.temporaryDirectory.appending(path: "drive_c-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: driveC) }

        try makeExe(at: driveC, "Program Files/AssaultCube/assaultcube.exe")
        try makeExe(at: driveC, "Program Files/AssaultCube/unins000.exe")  // excluded
        try makeExe(at: driveC, "Program Files (x86)/Cube/cube.exe")
        try makeExe(at: driveC, "Games/Quake/quake.exe")  // non-standard root
        try makeExe(at: driveC, "windows/system32/notepad.exe")  // system, skipped
        try makeExe(at: driveC, "Program Files/Redist/vc_redist.x64.exe")  // excluded

        let names = Set(InstalledProgramScanner.scan(driveC: driveC).map(\.name))

        #expect(names.contains("assaultcube"))
        #expect(names.contains("cube"))
        #expect(names.contains("quake"))
        #expect(!names.contains("unins000"))
        #expect(!names.contains("notepad"))
        #expect(!names.contains("vc_redist.x64"))
    }

    @Test func returnsEmptyForMissingDrive() {
        let missing = FileManager.default.temporaryDirectory.appending(path: "nope-\(UUID().uuidString)")
        #expect(InstalledProgramScanner.scan(driveC: missing).isEmpty)
    }

    private func makeExe(at driveC: URL, _ relativePath: String) throws {
        let url = driveC.appending(path: relativePath)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data([0x4D, 0x5A]).write(to: url)
    }
}
