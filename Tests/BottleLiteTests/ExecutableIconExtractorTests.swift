import Foundation
import Testing

@testable import BottleLite

struct ExecutableIconExtractorTests {
    @Test func invalidPEBytesReturnNil() {
        #expect(ExecutableIconExtractor.icoData(fromPEBytes: []) == nil)
        #expect(ExecutableIconExtractor.icoData(fromPEBytes: [0x4D, 0x5A]) == nil)
    }

    @Test func textFileReturnsNilIcon() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let url = directory.appendingPathComponent("not-pe.txt")
        try Data("hello".utf8).write(to: url)

        #expect(ExecutableIconExtractor.icon(forExecutableAt: url) == nil)
    }

    @Test func syntheticPEResourceBuildsICOData() throws {
        let ico = try #require(ExecutableIconExtractor.icoData(fromPEBytes: syntheticPEWithIcon()))

        #expect(Array(ico.prefix(4)) == [0x00, 0x00, 0x01, 0x00])
        #expect(ico.count == 70)
        #expect(ico[18] == 22)
    }

    private func syntheticPEWithIcon() -> [UInt8] {
        let peOffset = 0x80
        let optionalHeaderSize = 0xF0
        let sectionTableOffset = peOffset + 4 + 20 + optionalHeaderSize
        let resourceRawOffset = 0x200
        let resourceRVA = UInt32(0x1000)
        let resourceRawSize = UInt32(0x200)

        var bytes = [UInt8](repeating: 0, count: 0x400)
        writeUInt16(0x5A4D, to: &bytes, at: 0)
        writeUInt32(UInt32(peOffset), to: &bytes, at: 0x3C)

        writeUInt32(0x0000_4550, to: &bytes, at: peOffset)
        let coffOffset = peOffset + 4
        writeUInt16(0x8664, to: &bytes, at: coffOffset)
        writeUInt16(1, to: &bytes, at: coffOffset + 2)
        writeUInt16(UInt16(optionalHeaderSize), to: &bytes, at: coffOffset + 16)

        let optionalHeaderOffset = coffOffset + 20
        writeUInt16(0x020B, to: &bytes, at: optionalHeaderOffset)

        writeASCII(".rsrc", to: &bytes, at: sectionTableOffset)
        writeUInt32(resourceRawSize, to: &bytes, at: sectionTableOffset + 8)
        writeUInt32(resourceRVA, to: &bytes, at: sectionTableOffset + 12)
        writeUInt32(resourceRawSize, to: &bytes, at: sectionTableOffset + 16)
        writeUInt32(UInt32(resourceRawOffset), to: &bytes, at: sectionTableOffset + 20)

        let iconDirectory = 0x20
        let iconNameDirectory = 0x38
        let iconLanguageDirectory = 0x50
        let iconDataEntry = 0x68
        let groupDirectory = 0x78
        let groupNameDirectory = 0x90
        let groupLanguageDirectory = 0xA8
        let groupDataEntry = 0xC0
        let iconDataOffset = 0xD0
        let groupDataOffset = 0x100

        writeResourceDirectory(to: &bytes, base: resourceRawOffset, offset: 0, idEntries: 2)
        writeResourceEntry(nameID: 3, directoryOffset: iconDirectory, to: &bytes, at: resourceRawOffset + 16)
        writeResourceEntry(
            nameID: 14, directoryOffset: groupDirectory, to: &bytes, at: resourceRawOffset + 24)

        writeResourceDirectory(to: &bytes, base: resourceRawOffset, offset: iconDirectory, idEntries: 1)
        writeResourceEntry(
            nameID: 1, directoryOffset: iconNameDirectory, to: &bytes,
            at: resourceRawOffset + iconDirectory + 16)
        writeResourceDirectory(to: &bytes, base: resourceRawOffset, offset: iconNameDirectory, idEntries: 1)
        writeResourceEntry(
            nameID: 1033, directoryOffset: iconLanguageDirectory, to: &bytes,
            at: resourceRawOffset + iconNameDirectory + 16)
        writeResourceDirectory(
            to: &bytes, base: resourceRawOffset, offset: iconLanguageDirectory, idEntries: 1)
        writeDataEntry(
            nameID: 1033, dataEntryOffset: iconDataEntry, to: &bytes,
            at: resourceRawOffset + iconLanguageDirectory + 16)

        writeResourceDirectory(to: &bytes, base: resourceRawOffset, offset: groupDirectory, idEntries: 1)
        writeResourceEntry(
            nameID: 1, directoryOffset: groupNameDirectory, to: &bytes,
            at: resourceRawOffset + groupDirectory + 16)
        writeResourceDirectory(to: &bytes, base: resourceRawOffset, offset: groupNameDirectory, idEntries: 1)
        writeResourceEntry(
            nameID: 1033, directoryOffset: groupLanguageDirectory, to: &bytes,
            at: resourceRawOffset + groupNameDirectory + 16)
        writeResourceDirectory(
            to: &bytes, base: resourceRawOffset, offset: groupLanguageDirectory, idEntries: 1)
        writeDataEntry(
            nameID: 1033, dataEntryOffset: groupDataEntry, to: &bytes,
            at: resourceRawOffset + groupLanguageDirectory + 16)

        let iconImage = onePixelIconDIB()
        writeUInt32(resourceRVA + UInt32(iconDataOffset), to: &bytes, at: resourceRawOffset + iconDataEntry)
        writeUInt32(UInt32(iconImage.count), to: &bytes, at: resourceRawOffset + iconDataEntry + 4)
        bytes.replaceSubrange(
            (resourceRawOffset + iconDataOffset)..<(resourceRawOffset + iconDataOffset + iconImage.count),
            with: iconImage
        )

        let groupIcon = groupIconResource(imageSize: UInt32(iconImage.count), resourceID: 1)
        writeUInt32(resourceRVA + UInt32(groupDataOffset), to: &bytes, at: resourceRawOffset + groupDataEntry)
        writeUInt32(UInt32(groupIcon.count), to: &bytes, at: resourceRawOffset + groupDataEntry + 4)
        bytes.replaceSubrange(
            (resourceRawOffset + groupDataOffset)..<(resourceRawOffset + groupDataOffset + groupIcon.count),
            with: groupIcon
        )

        return bytes
    }

    private func writeResourceDirectory(to bytes: inout [UInt8], base: Int, offset: Int, idEntries: UInt16) {
        writeUInt16(idEntries, to: &bytes, at: base + offset + 14)
    }

    private func writeResourceEntry(
        nameID: UInt32, directoryOffset: Int, to bytes: inout [UInt8], at offset: Int
    ) {
        writeUInt32(nameID, to: &bytes, at: offset)
        writeUInt32(0x8000_0000 | UInt32(directoryOffset), to: &bytes, at: offset + 4)
    }

    private func writeDataEntry(nameID: UInt32, dataEntryOffset: Int, to bytes: inout [UInt8], at offset: Int)
    {
        writeUInt32(nameID, to: &bytes, at: offset)
        writeUInt32(UInt32(dataEntryOffset), to: &bytes, at: offset + 4)
    }

    private func groupIconResource(imageSize: UInt32, resourceID: UInt16) -> [UInt8] {
        var bytes: [UInt8] = []
        appendUInt16(0, to: &bytes)
        appendUInt16(1, to: &bytes)
        appendUInt16(1, to: &bytes)
        bytes.append(contentsOf: [1, 1, 0, 0])
        appendUInt16(1, to: &bytes)
        appendUInt16(32, to: &bytes)
        appendUInt32(imageSize, to: &bytes)
        appendUInt16(resourceID, to: &bytes)
        return bytes
    }

    private func onePixelIconDIB() -> [UInt8] {
        var bytes: [UInt8] = []
        appendUInt32(40, to: &bytes)
        appendUInt32(1, to: &bytes)
        appendUInt32(2, to: &bytes)
        appendUInt16(1, to: &bytes)
        appendUInt16(32, to: &bytes)
        appendUInt32(0, to: &bytes)
        appendUInt32(4, to: &bytes)
        appendUInt32(0, to: &bytes)
        appendUInt32(0, to: &bytes)
        appendUInt32(0, to: &bytes)
        appendUInt32(0, to: &bytes)
        bytes.append(contentsOf: [0, 0, 255, 255])
        bytes.append(contentsOf: [0, 0, 0, 0])
        return bytes
    }

    private func writeASCII(_ string: String, to bytes: inout [UInt8], at offset: Int) {
        for (index, byte) in string.utf8.enumerated() {
            bytes[offset + index] = byte
        }
    }

    private func writeUInt16(_ value: UInt16, to bytes: inout [UInt8], at offset: Int) {
        bytes[offset] = UInt8(value & 0xFF)
        bytes[offset + 1] = UInt8((value >> 8) & 0xFF)
    }

    private func writeUInt32(_ value: UInt32, to bytes: inout [UInt8], at offset: Int) {
        bytes[offset] = UInt8(value & 0xFF)
        bytes[offset + 1] = UInt8((value >> 8) & 0xFF)
        bytes[offset + 2] = UInt8((value >> 16) & 0xFF)
        bytes[offset + 3] = UInt8((value >> 24) & 0xFF)
    }

    private func appendUInt16(_ value: UInt16, to bytes: inout [UInt8]) {
        bytes.append(UInt8(value & 0xFF))
        bytes.append(UInt8((value >> 8) & 0xFF))
    }

    private func appendUInt32(_ value: UInt32, to bytes: inout [UInt8]) {
        bytes.append(UInt8(value & 0xFF))
        bytes.append(UInt8((value >> 8) & 0xFF))
        bytes.append(UInt8((value >> 16) & 0xFF))
        bytes.append(UInt8((value >> 24) & 0xFF))
    }
}
