import Foundation

protocol BottleStoring: Sendable {
    func load() -> [Bottle]
    func save(_ bottles: [Bottle])
}

/// Persists bottle records as JSON under Application Support. Saves are written
/// atomically so a crash mid-write cannot corrupt the store.
struct BottleRepository: BottleStoring {
    /// Overrides the default Application Support location; used by tests so they
    /// never read or clobber the real `bottles.json`.
    private let fileURLOverride: URL?

    init(fileURLOverride: URL? = nil) {
        self.fileURLOverride = fileURLOverride
    }

    private func resolveURL() -> URL? {
        if let fileURLOverride { return fileURLOverride }
        return try? BottleStorage.bottlesFileURL()
    }

    func load() -> [Bottle] {
        guard
            let url = resolveURL(),
            let data = try? Data(contentsOf: url)
        else {
            return []
        }

        do {
            return try Self.decoder.decode([Bottle].self, from: data)
        } catch {
            return []
        }
    }

    func save(_ bottles: [Bottle]) {
        guard
            let url = resolveURL(),
            let data = try? Self.encoder.encode(bottles)
        else {
            return
        }
        try? data.write(to: url, options: [.atomic])
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
