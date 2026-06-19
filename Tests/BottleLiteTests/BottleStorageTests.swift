import Foundation
import Testing

@testable import BottleLite

struct BottleStorageTests {
    @Test func readOnlyPrefixLookupDoesNotCreateBottleDirectory() throws {
        let fm = FileManager.default
        let bottle = Bottle(name: "Read Only")

        let prefix = try BottleStorage.prefixURL(for: bottle, using: fm, create: false)
        defer { try? fm.removeItem(at: prefix) }

        #expect(!fm.fileExists(atPath: prefix.path))
    }
}
