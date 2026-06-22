import Foundation

/// The Direct3D translation layer a bottle uses. Selecting one persists the
/// choice and applies the matching Wine DLL overrides at launch. Full speedups
/// also require the backend's libraries to be present (DXVK component / a Game
/// Porting Toolkit Wine build) — the setting is the control surface for that.
enum GraphicsBackend: String, Codable, CaseIterable, Identifiable, Sendable {
    case wineD3D
    case dxvk
    case d3dMetal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .wineD3D: "Built-in (WineD3D)"
        case .dxvk: "DXVK"
        case .d3dMetal: "D3DMetal"
        }
    }

    var detail: String {
        switch self {
        case .wineD3D:
            "Most compatible. Translates DirectX via OpenGL. Slowest for 3D games."
        case .dxvk:
            "DirectX 9–11 → Vulkan. Faster for many games. Add the DXVK component below."
        case .d3dMetal:
            "DirectX 11/12 → Metal (fastest). Requires a Game Porting Toolkit Wine build."
        }
    }

    /// Wine DLL override string so the prefix prefers the translation layer's
    /// DLLs over the built-in ones. `nil` for the built-in backend.
    var dllOverrides: String? {
        switch self {
        case .wineD3D: nil
        // DXVK: prefer the native DXVK DLLs copied into the prefix.
        case .dxvk: "dxgi,d3d9,d3d10core,d3d11=n,b"
        // D3DMetal: force Wine's *builtin* DLLs, which in a Game Porting Toolkit
        // Wine are the D3DMetal implementation. Builtin-only (`=b`) so any DXVK
        // DLLs left in the prefix can't shadow them. Includes d3d12 for DX12.
        case .d3dMetal: "d3d9,d3d10core,d3d11,d3d12,dxgi=b"
        }
    }

    /// Whether Apple's Game Porting Toolkit (D3DMetal) appears to be installed.
    /// Best-effort: checks the libraries GPTK ships under common Homebrew prefixes.
    static var isD3DMetalAvailable: Bool {
        let gptk = "/Applications/Game Porting Toolkit.app/Contents/Resources/wine"
        let candidates = [
            "/opt/homebrew/lib/external/libd3dshared.dylib",
            "/opt/homebrew/lib/libd3dshared.dylib",
            "/usr/local/lib/external/libd3dshared.dylib",
            "/usr/local/lib/libd3dshared.dylib",
            // Gcenx prebuilt GPTK ships D3DMetal inside its app bundle.
            "\(gptk)/lib/external/libd3dshared.dylib",
            "\(gptk)/lib/wine/x86_64-unix/libd3dshared.dylib",
        ]
        if candidates.contains(where: { FileManager.default.fileExists(atPath: $0) }) {
            return true
        }
        // Fall back to "the GPTK app is installed at all": its wine64 implies
        // D3DMetal even if the dylib lives at a layout we don't enumerate.
        return FileManager.default.isExecutableFile(atPath: "\(gptk)/bin/wine64")
    }
}
