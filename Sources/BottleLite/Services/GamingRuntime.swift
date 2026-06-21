import Foundation

/// Detects the macOS graphics libraries that make the DXVK/D3DMetal backends
/// actually run games — MoltenVK (Vulkan → Metal) for DXVK, and Apple's Game
/// Porting Toolkit for D3DMetal — and builds the environment a Wine launch needs
/// to find them. Plain Homebrew Wine has none of this, which is why DX games
/// otherwise hang or exit.
enum GamingRuntime {
    static let brewPrefixes = ["/opt/homebrew", "/usr/local"]

    /// Gcenx's prebuilt Game Porting Toolkit app bundle. It ships a
    /// CrossOver-lineage Wine (which runs the modern Steam client) plus
    /// D3DMetal, so we treat its presence as "gaming-grade Wine installed".
    static let gptkAppRoot = "/Applications/Game Porting Toolkit.app/Contents/Resources/wine"
    static var gptkAppWine64: String { "\(gptkAppRoot)/bin/wine64" }

    /// Whether the Gcenx GPTK app bundle (CrossOver Wine + D3DMetal) is present.
    static var isGPTKAppInstalled: Bool {
        FileManager.default.isExecutableFile(atPath: gptkAppWine64)
    }

    /// Path to the MoltenVK ICD manifest if it's installed (e.g. via
    /// `brew install molten-vk`), else nil. Homebrew puts it under `etc/`.
    static var moltenVKICD: String? {
        firstExisting([
            "/etc/vulkan/icd.d/MoltenVK_icd.json",
            "/opt/molten-vk/etc/vulkan/icd.d/MoltenVK_icd.json",
            "/share/vulkan/icd.d/MoltenVK_icd.json",
            "/opt/molten-vk/share/vulkan/icd.d/MoltenVK_icd.json",
        ])
    }

    /// Path to libMoltenVK.dylib if installed.
    static var moltenVKDylib: String? {
        firstExisting(["/lib/libMoltenVK.dylib", "/opt/molten-vk/lib/libMoltenVK.dylib"])
    }

    static var isMoltenVKInstalled: Bool { moltenVKICD != nil || moltenVKDylib != nil }

    static var isGPTKInstalled: Bool { GraphicsBackend.isD3DMetalAvailable }

    /// Whether the given Wine binary is a Game Porting Toolkit (x86 / Rosetta)
    /// build. This matters because DXVK can't run on it: Homebrew's MoltenVK is
    /// arm64 and a Rosetta x86 process can't load an arm64 dylib. On GPTK Wine,
    /// D3DMetal is the only working accelerated backend.
    static func isGPTKWine(_ path: String) -> Bool {
        path.contains("Game Porting Toolkit")
            || path == "/opt/homebrew/bin/wine64"
            || path == "/usr/local/bin/wine64"
    }

    /// Whether any gaming-grade Wine (GPTK app bundle, Apple GPTK build, or
    /// Gcenx CrossOver Wine) is present. Plain Homebrew `wine-stable` is not
    /// enough to run the modern Steam client — this is.
    static var isGamingWineInstalled: Bool {
        let gamingWines = [
            gptkAppWine64,
            "/opt/homebrew/opt/game-porting-toolkit/bin/wine64",
            "/usr/local/opt/game-porting-toolkit/bin/wine64",
            "/Applications/Wine Crossover.app/Contents/Resources/wine/bin/wine64",
        ]
        return gamingWines.contains { FileManager.default.isExecutableFile(atPath: $0) }
    }

    /// Homebrew lib directories that may hold libMoltenVK / libvulkan / GPTK.
    static var librarySearchPaths: [String] {
        brewPrefixes.map { "\($0)/lib" }.filter { FileManager.default.fileExists(atPath: $0) }
    }

    /// Extra launch environment so the chosen backend's libraries are
    /// discoverable. Empty for the built-in renderer or when nothing is installed.
    static func environment(for backend: GraphicsBackend) -> [String: String] {
        var env: [String: String] = [:]

        switch backend {
        case .wineD3D:
            return env
        case .dxvk:
            if let icd = moltenVKICD {
                env["VK_ICD_FILENAMES"] = icd
            }
        case .d3dMetal:
            break
        }

        if backend != .wineD3D, !librarySearchPaths.isEmpty {
            let existing = ProcessInfo.processInfo.environment["DYLD_FALLBACK_LIBRARY_PATH"]
            let parts = librarySearchPaths + ["/usr/lib"] + (existing.map { [$0] } ?? [])
            env["DYLD_FALLBACK_LIBRARY_PATH"] = parts.joined(separator: ":")
        }

        return env
    }

    private static func firstExisting(_ suffixes: [String]) -> String? {
        for prefix in brewPrefixes {
            for suffix in suffixes {
                let path = prefix + suffix
                if FileManager.default.fileExists(atPath: path) { return path }
            }
        }
        return nil
    }
}
