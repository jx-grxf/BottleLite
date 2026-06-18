import Foundation

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
}
