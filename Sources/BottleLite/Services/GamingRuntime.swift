import Foundation

/// Detects the macOS graphics libraries that make the DXVK/D3DMetal backends
/// actually run games — MoltenVK (Vulkan → Metal) for DXVK, and Apple's Game
/// Porting Toolkit for D3DMetal — and builds the environment a Wine launch needs
/// to find them. Plain Homebrew Wine has none of this, which is why DX games
/// otherwise hang or exit.
enum GamingRuntime {
    static let brewPrefixes = ["/opt/homebrew", "/usr/local"]

    /// Path to the MoltenVK ICD manifest if it's installed (e.g. via
    /// `brew install molten-vk`), else nil.
    static var moltenVKICD: String? {
        firstExisting([
            "/share/vulkan/icd.d/MoltenVK_icd.json",
            "/opt/molten-vk/share/vulkan/icd.d/MoltenVK_icd.json",
        ])
    }

    static var isMoltenVKInstalled: Bool { moltenVKICD != nil }

    static var isGPTKInstalled: Bool { GraphicsBackend.isD3DMetalAvailable }

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
