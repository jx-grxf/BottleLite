import Foundation
import UniformTypeIdentifiers

enum WindowsFileKind: Equatable {
    case executable
    case installerPackage

    init?(url: URL) {
        switch url.pathExtension.lowercased() {
        case "exe":
            self = .executable
        case "msi":
            self = .installerPackage
        default:
            return nil
        }
    }
}

extension URL {
    var windowsFileKind: WindowsFileKind? {
        WindowsFileKind(url: self)
    }
}

extension UTType {
    static let windowsExecutable = UTType(filenameExtension: "exe") ?? .data
    static let windowsInstallerPackage = UTType(filenameExtension: "msi") ?? .data

    static let importableWindowsFileTypes: [UTType] = [
        .windowsExecutable,
        .windowsInstallerPackage,
    ]
}
