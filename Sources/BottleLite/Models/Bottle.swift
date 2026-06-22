import Foundation

struct Bottle: Identifiable, Hashable, Codable {
    var id: UUID
    var name: String
    var createdAt: Date
    var programs: [WindowsProgram]
    /// When on, programs in this bottle launch with extra performance tuning
    /// (msync/esync, large-address-aware, high QoS, a power assertion, and the
    /// Metal FPS overlay). See `WineProgramRunner`.
    var gameMode: Bool
    /// The Direct3D translation layer programs in this bottle launch with.
    var graphicsBackend: GraphicsBackend
    /// An explicit Wine binary this bottle should launch with, overriding the
    /// auto-detected runtime. Used to run 32-bit/OpenGL games on a plain Wine
    /// when the preferred runtime (GPTK) can't run them. `nil` means automatic.
    var winePathOverride: String?

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = .now,
        programs: [WindowsProgram] = [],
        gameMode: Bool = false,
        graphicsBackend: GraphicsBackend = .wineD3D,
        winePathOverride: String? = nil
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.programs = programs
        self.gameMode = gameMode
        self.graphicsBackend = graphicsBackend
        self.winePathOverride = winePathOverride
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, createdAt, programs, gameMode, graphicsBackend, winePathOverride
    }

    // Custom decode so bottles persisted before these fields existed still load.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        programs = try container.decodeIfPresent([WindowsProgram].self, forKey: .programs) ?? []
        gameMode = try container.decodeIfPresent(Bool.self, forKey: .gameMode) ?? false
        graphicsBackend =
            try container.decodeIfPresent(GraphicsBackend.self, forKey: .graphicsBackend) ?? .wineD3D
        winePathOverride = try container.decodeIfPresent(String.self, forKey: .winePathOverride)
    }
}

struct WindowsProgram: Identifiable, Hashable, Codable {
    var id: UUID
    var name: String
    var path: String
    var importedAt: Date
    var validation: ExecutableValidation
    /// Raw command-line arguments passed after the executable, e.g. `-fullscreen`.
    var arguments: String
    /// When true the program is launched inside Terminal.app so its console
    /// output is visible and interactive (auto-detected for CUI executables).
    var runsInTerminal: Bool

    init(
        id: UUID = UUID(),
        name: String,
        path: String,
        importedAt: Date = .now,
        validation: ExecutableValidation,
        arguments: String = "",
        runsInTerminal: Bool = false
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.importedAt = importedAt
        self.validation = validation
        self.arguments = arguments
        self.runsInTerminal = runsInTerminal
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, path, importedAt, validation, arguments, runsInTerminal
    }

    // Custom decode so programs persisted before these fields existed still load.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        path = try container.decode(String.self, forKey: .path)
        importedAt = try container.decode(Date.self, forKey: .importedAt)
        validation = try container.decode(ExecutableValidation.self, forKey: .validation)
        arguments = try container.decodeIfPresent(String.self, forKey: .arguments) ?? ""
        runsInTerminal = try container.decodeIfPresent(Bool.self, forKey: .runsInTerminal) ?? false
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
