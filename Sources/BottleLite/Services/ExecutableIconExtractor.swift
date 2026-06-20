import AppKit
import Foundation

enum ExecutableIconExtractor {
    /// Best-resolution embedded application icon for a Windows PE (.exe/.dll), or nil.
    static func icon(forExecutableAt url: URL) -> NSImage? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        guard let ico = icoData(fromPEBytes: [UInt8](data)) else { return nil }
        return NSImage(data: ico)
    }

    /// Pure, testable helper: given the full bytes of a PE file, return a valid
    /// .ico container (header + best RT_ICON images) assembled from its resources, or nil.
    static func icoData(fromPEBytes bytes: [UInt8]) -> Data? {
        PEIconResourceParser(bytes: bytes).icoData()
    }
}

private struct PEIconResourceParser {
    private static let dosMagic: UInt16 = 0x5A4D
    private static let pe32Magic: UInt16 = 0x010B
    private static let pe32PlusMagic: UInt16 = 0x020B
    private static let resourceTypeIcon: UInt16 = 3
    private static let resourceTypeGroupIcon: UInt16 = 14

    let bytes: [UInt8]

    func icoData() -> Data? {
        guard let resourceSection = resourceSection() else { return nil }
        let resources = ResourceDirectory(bytes: bytes, section: resourceSection)

        guard
            let groupTypeDirectory = resources.directory(
                forID: Self.resourceTypeGroupIcon, in: resourceSection.rawOffset),
            let groupDataEntry = resources.firstDataEntry(in: groupTypeDirectory, maxDepth: 3),
            let groupData = resources.data(for: groupDataEntry),
            let groupIcon = GroupIcon(data: groupData)
        else {
            return nil
        }

        guard
            let iconTypeDirectory = resources.directory(
                forID: Self.resourceTypeIcon, in: resourceSection.rawOffset)
        else {
            return nil
        }

        var iconImages: [(entry: GroupIcon.Entry, data: Data)] = []
        for entry in groupIcon.entries {
            guard let iconNameDirectory = resources.directory(forID: entry.resourceID, in: iconTypeDirectory),
                let iconDataEntry = resources.firstDataEntry(in: iconNameDirectory, maxDepth: 2),
                let iconData = resources.data(for: iconDataEntry)
            else {
                continue
            }
            iconImages.append((entry, iconData))
        }

        guard !iconImages.isEmpty else { return nil }
        return makeICO(from: iconImages)
    }

    private func resourceSection() -> Section? {
        guard bytes.count >= 0x40, readUInt16(at: 0) == Self.dosMagic else { return nil }
        guard let peOffsetValue = readUInt32(at: 0x3C), peOffsetValue <= UInt32(Int32.max) else { return nil }

        let peOffset = Int(peOffsetValue)
        guard readUInt32(at: peOffset) == 0x0000_4550 else { return nil }

        let coffOffset = peOffset + 4
        guard let sectionCountValue = readUInt16(at: coffOffset + 2),
            let optionalHeaderSizeValue = readUInt16(at: coffOffset + 16)
        else {
            return nil
        }

        let sectionCount = Int(sectionCountValue)
        let optionalHeaderSize = Int(optionalHeaderSizeValue)
        let optionalHeaderOffset = coffOffset + 20
        guard let optionalMagic = readUInt16(at: optionalHeaderOffset),
            optionalMagic == Self.pe32Magic || optionalMagic == Self.pe32PlusMagic
        else {
            return nil
        }

        guard rangeIsValid(offset: optionalHeaderOffset, count: optionalHeaderSize) else { return nil }
        let sectionTableOffset = optionalHeaderOffset + optionalHeaderSize

        for index in 0..<sectionCount {
            let sectionOffset = sectionTableOffset + index * 40
            guard rangeIsValid(offset: sectionOffset, count: 40) else { return nil }
            let name = sectionName(at: sectionOffset)
            guard name == ".rsrc" else { continue }

            guard let virtualSize = readUInt32(at: sectionOffset + 8),
                let virtualAddress = readUInt32(at: sectionOffset + 12),
                let rawSize = readUInt32(at: sectionOffset + 16),
                let rawPointer = readUInt32(at: sectionOffset + 20)
            else {
                return nil
            }

            guard rawPointer <= UInt32(Int32.max), rawSize <= UInt32(Int32.max) else { return nil }
            let rawOffset = Int(rawPointer)
            let rawCount = Int(rawSize)
            guard rawCount > 0, rangeIsValid(offset: rawOffset, count: rawCount) else { return nil }
            return Section(
                virtualAddress: virtualAddress,
                virtualSize: virtualSize,
                rawOffset: rawOffset,
                rawSize: rawSize
            )
        }

        return nil
    }

    private func makeICO(from iconImages: [(entry: GroupIcon.Entry, data: Data)]) -> Data? {
        guard iconImages.count <= Int(UInt16.max) else { return nil }

        let imageOffsetStart = 6 + iconImages.count * 16
        var nextImageOffset = imageOffsetStart
        var directory = Data()
        directory.appendUInt16LE(0)
        directory.appendUInt16LE(1)
        directory.appendUInt16LE(UInt16(iconImages.count))

        var imagePayload = Data()
        for image in iconImages {
            guard image.data.count <= Int(UInt32.max), nextImageOffset <= Int(UInt32.max) else { return nil }

            directory.append(image.entry.width)
            directory.append(image.entry.height)
            directory.append(image.entry.colorCount)
            directory.append(0)
            directory.appendUInt16LE(image.entry.planes)
            directory.appendUInt16LE(image.entry.bitCount)
            directory.appendUInt32LE(UInt32(image.data.count))
            directory.appendUInt32LE(UInt32(nextImageOffset))

            imagePayload.append(image.data)
            nextImageOffset += image.data.count
        }

        directory.append(imagePayload)
        return directory
    }

    private func sectionName(at offset: Int) -> String {
        guard rangeIsValid(offset: offset, count: 8) else { return "" }
        let nameBytes = bytes[offset..<(offset + 8)].prefix { $0 != 0 }
        return String(bytes: nameBytes, encoding: .ascii) ?? ""
    }

    private func readUInt16(at offset: Int) -> UInt16? {
        guard rangeIsValid(offset: offset, count: 2) else { return nil }
        return UInt16(bytes[offset]) | UInt16(bytes[offset + 1]) << 8
    }

    private func readUInt32(at offset: Int) -> UInt32? {
        guard rangeIsValid(offset: offset, count: 4) else { return nil }
        return UInt32(bytes[offset])
            | UInt32(bytes[offset + 1]) << 8
            | UInt32(bytes[offset + 2]) << 16
            | UInt32(bytes[offset + 3]) << 24
    }

    private func rangeIsValid(offset: Int, count: Int) -> Bool {
        offset >= 0 && count >= 0 && offset <= bytes.count && count <= bytes.count - offset
    }
}

private struct Section {
    let virtualAddress: UInt32
    let virtualSize: UInt32
    let rawOffset: Int
    let rawSize: UInt32

    var mappedSize: UInt32 {
        max(virtualSize, rawSize)
    }
}

private struct ResourceDirectory {
    private let bytes: [UInt8]
    private let section: Section

    init(bytes: [UInt8], section: Section) {
        self.bytes = bytes
        self.section = section
    }

    func directory(forID id: UInt16, in directoryOffset: Int) -> Int? {
        for entry in entries(in: directoryOffset) {
            guard !entry.nameIsString, UInt16(entry.name & 0xFFFF) == id, entry.valueIsDirectory else {
                continue
            }
            return resourceOffsetToFileOffset(entry.value & 0x7FFF_FFFF)
        }
        return nil
    }

    func firstDataEntry(in directoryOffset: Int, maxDepth: Int) -> Int? {
        guard maxDepth >= 0 else { return nil }

        for entry in entries(in: directoryOffset) {
            if entry.valueIsDirectory {
                guard let childOffset = resourceOffsetToFileOffset(entry.value & 0x7FFF_FFFF) else {
                    continue
                }
                if let dataEntry = firstDataEntry(in: childOffset, maxDepth: maxDepth - 1) {
                    return dataEntry
                }
            } else if let dataEntry = resourceOffsetToFileOffset(entry.value) {
                return dataEntry
            }
        }

        return nil
    }

    func data(for dataEntryOffset: Int) -> Data? {
        guard rangeIsValid(offset: dataEntryOffset, count: 16),
            let dataRVA = readUInt32(at: dataEntryOffset),
            let size = readUInt32(at: dataEntryOffset + 4),
            let fileOffset = rvaToFileOffset(dataRVA)
        else {
            return nil
        }

        guard size <= UInt32(Int32.max) else { return nil }
        let count = Int(size)
        guard rangeIsValid(offset: fileOffset, count: count) else { return nil }
        return Data(bytes[fileOffset..<(fileOffset + count)])
    }

    private func entries(in directoryOffset: Int) -> [Entry] {
        guard rangeIsValid(offset: directoryOffset, count: 16),
            let namedCount = readUInt16(at: directoryOffset + 12),
            let idCount = readUInt16(at: directoryOffset + 14)
        else {
            return []
        }

        let totalCount = Int(namedCount) + Int(idCount)
        guard totalCount > 0 else { return [] }

        let entriesOffset = directoryOffset + 16
        guard rangeIsValid(offset: entriesOffset, count: totalCount * 8) else { return [] }

        var entries: [Entry] = []
        entries.reserveCapacity(totalCount)
        for index in 0..<totalCount {
            let offset = entriesOffset + index * 8
            guard let name = readUInt32(at: offset), let value = readUInt32(at: offset + 4) else { return [] }
            entries.append(Entry(name: name, value: value))
        }
        return entries
    }

    private func resourceOffsetToFileOffset(_ offset: UInt32) -> Int? {
        guard offset <= section.rawSize, offset <= UInt32(Int32.max) else { return nil }
        let fileOffset = section.rawOffset + Int(offset)
        guard rangeIsValid(offset: fileOffset, count: 0) else { return nil }
        return fileOffset
    }

    private func rvaToFileOffset(_ rva: UInt32) -> Int? {
        guard rva >= section.virtualAddress else { return nil }
        let offset = rva - section.virtualAddress
        guard offset < section.mappedSize, offset <= UInt32(Int32.max) else { return nil }

        let fileOffset = section.rawOffset + Int(offset)
        guard rangeIsValid(offset: fileOffset, count: 0) else { return nil }
        return fileOffset
    }

    private func readUInt16(at offset: Int) -> UInt16? {
        guard rangeIsValid(offset: offset, count: 2) else { return nil }
        return UInt16(bytes[offset]) | UInt16(bytes[offset + 1]) << 8
    }

    private func readUInt32(at offset: Int) -> UInt32? {
        guard rangeIsValid(offset: offset, count: 4) else { return nil }
        return UInt32(bytes[offset])
            | UInt32(bytes[offset + 1]) << 8
            | UInt32(bytes[offset + 2]) << 16
            | UInt32(bytes[offset + 3]) << 24
    }

    private func rangeIsValid(offset: Int, count: Int) -> Bool {
        offset >= 0 && count >= 0 && offset <= bytes.count && count <= bytes.count - offset
    }

    private struct Entry {
        let name: UInt32
        let value: UInt32

        var nameIsString: Bool {
            name & 0x8000_0000 != 0
        }

        var valueIsDirectory: Bool {
            value & 0x8000_0000 != 0
        }
    }
}

private struct GroupIcon {
    let entries: [Entry]

    init?(data: Data) {
        let bytes = [UInt8](data)
        guard bytes.count >= 6,
            Self.readUInt16(in: bytes, at: 0) == 0,
            Self.readUInt16(in: bytes, at: 2) == 1,
            let count = Self.readUInt16(in: bytes, at: 4)
        else {
            return nil
        }

        let entryCount = Int(count)
        guard entryCount > 0, 6 + entryCount * 14 <= bytes.count else { return nil }

        var entries: [Entry] = []
        entries.reserveCapacity(entryCount)
        for index in 0..<entryCount {
            let offset = 6 + index * 14
            guard let planes = Self.readUInt16(in: bytes, at: offset + 4),
                let bitCount = Self.readUInt16(in: bytes, at: offset + 6),
                let bytesInResource = Self.readUInt32(in: bytes, at: offset + 8),
                let resourceID = Self.readUInt16(in: bytes, at: offset + 12)
            else {
                return nil
            }

            entries.append(
                Entry(
                    width: bytes[offset],
                    height: bytes[offset + 1],
                    colorCount: bytes[offset + 2],
                    planes: planes,
                    bitCount: bitCount,
                    bytesInResource: bytesInResource,
                    resourceID: resourceID
                )
            )
        }

        self.entries = entries
    }

    private static func readUInt16(in bytes: [UInt8], at offset: Int) -> UInt16? {
        guard offset >= 0, offset + 1 < bytes.count else { return nil }
        return UInt16(bytes[offset]) | UInt16(bytes[offset + 1]) << 8
    }

    private static func readUInt32(in bytes: [UInt8], at offset: Int) -> UInt32? {
        guard offset >= 0, offset + 3 < bytes.count else { return nil }
        return UInt32(bytes[offset])
            | UInt32(bytes[offset + 1]) << 8
            | UInt32(bytes[offset + 2]) << 16
            | UInt32(bytes[offset + 3]) << 24
    }

    struct Entry {
        let width: UInt8
        let height: UInt8
        let colorCount: UInt8
        let planes: UInt16
        let bitCount: UInt16
        let bytesInResource: UInt32
        let resourceID: UInt16
    }
}

private extension Data {
    mutating func appendUInt16LE(_ value: UInt16) {
        append(UInt8(value & 0xFF))
        append(UInt8((value >> 8) & 0xFF))
    }

    mutating func appendUInt32LE(_ value: UInt32) {
        append(UInt8(value & 0xFF))
        append(UInt8((value >> 8) & 0xFF))
        append(UInt8((value >> 16) & 0xFF))
        append(UInt8((value >> 24) & 0xFF))
    }
}
