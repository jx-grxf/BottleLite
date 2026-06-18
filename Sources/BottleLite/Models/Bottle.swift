import Foundation

struct Bottle: Identifiable, Hashable, Codable {
    var id: UUID
    var name: String
    var createdAt: Date
    var programs: [WindowsProgram]

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = .now,
        programs: [WindowsProgram] = []
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.programs = programs
    }
}

struct WindowsProgram: Identifiable, Hashable, Codable {
    var id: UUID
    var name: String
    var path: String
    var importedAt: Date
    var validation: ExecutableValidation

    init(
        id: UUID = UUID(),
        name: String,
        path: String,
        importedAt: Date = .now,
        validation: ExecutableValidation
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.importedAt = importedAt
        self.validation = validation
    }
}

enum ExecutableValidation: String, Codable {
    case valid
    case wrongExtension
    case missingMagic
    case unreadable

    var label: String {
        switch self {
        case .valid: "Ready"
        case .wrongExtension: "Not an .exe"
        case .missingMagic: "Not a Windows executable"
        case .unreadable: "Unreadable"
        }
    }
}
