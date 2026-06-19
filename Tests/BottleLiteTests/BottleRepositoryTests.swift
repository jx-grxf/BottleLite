import Foundation
import Testing

@testable import BottleLite

struct BottleRepositoryTests {
    @Test func roundTripsBottlesThroughDisk() throws {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "bottles-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }

        let repository = BottleRepository(fileURLOverride: url)
        let original = [
            Bottle(
                name: "Games",
                programs: [
                    WindowsProgram(name: "Setup", path: "/tmp/setup.exe", validation: .valid)
                ]),
            Bottle(name: "Tools"),
        ]

        repository.save(original)
        let loaded = repository.load()

        // Compare stable identity fields rather than full `==`: the ISO-8601
        // date encoding (chosen for a readable store) truncates sub-second
        // precision, which the app never relies on.
        #expect(loaded.map(\.id) == original.map(\.id))
        #expect(loaded.map(\.name) == ["Games", "Tools"])
        #expect(loaded.first?.programs.map(\.path) == ["/tmp/setup.exe"])
        #expect(loaded.first?.programs.first?.validation == .valid)
    }

    @Test func loadReturnsEmptyWhenFileMissing() {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "missing-\(UUID().uuidString).json")
        let repository = BottleRepository(fileURLOverride: url)
        #expect(repository.load().isEmpty)
    }

    @Test func corruptStoreIsQuarantinedBeforeDefaultRewrite() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "corrupt-store-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: "bottles.json")
        try Data("{ not json".utf8).write(to: url)

        let repository = BottleRepository(fileURLOverride: url)
        #expect(repository.load().isEmpty)
        #expect(!FileManager.default.fileExists(atPath: url.path))

        let backups = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        #expect(backups.contains { $0.hasPrefix("bottles.corrupt-") && $0.hasSuffix(".json") })
    }
}
