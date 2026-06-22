import Foundation

/// A starting template for a new bottle, surfaced from the "+" menu so users
/// don't have to know which settings a kind of app needs.
enum BottleType: String, CaseIterable, Identifiable {
    case windowsApp
    case steamGame
    case oldGame
    case consoleTool
    case advanced

    var id: String { rawValue }

    var title: String {
        switch self {
        case .windowsApp: "Windows App"
        case .steamGame: "Steam Game"
        case .oldGame: "Old Game (DirectX 9)"
        case .consoleTool: "Console Tool"
        case .advanced: "Empty Bottle"
        }
    }

    var systemImage: String {
        switch self {
        case .windowsApp: "app.badge"
        case .steamGame: "gamecontroller"
        case .oldGame: "dpad"
        case .consoleTool: "terminal"
        case .advanced: "shippingbox"
        }
    }

    var detail: String {
        switch self {
        case .windowsApp: "A regular Windows application."
        case .steamGame: "Tuned for gaming: Game Mode on, fastest available graphics."
        case .oldGame: "Older DirectX 9 titles, with Game Mode on."
        case .consoleTool: "A command-line Windows tool."
        case .advanced: "A clean bottle you configure yourself."
        }
    }

    var defaultName: String {
        switch self {
        case .windowsApp: "Windows App"
        case .steamGame: "Steam"
        case .oldGame: "Old Game"
        case .consoleTool: "Console Tool"
        case .advanced: "New Bottle"
        }
    }

    var gameMode: Bool {
        switch self {
        case .steamGame, .oldGame: true
        case .windowsApp, .consoleTool, .advanced: false
        }
    }

    var graphicsBackend: GraphicsBackend {
        switch self {
        case .steamGame:
            // With a Game Porting Toolkit Wine (x86), DXVK can't load the arm64
            // MoltenVK, so D3DMetal is the only working accelerated backend.
            // Fall back to DXVK when only a native Wine + MoltenVK is present.
            GraphicsBackend.isD3DMetalAvailable ? .d3dMetal : .dxvk
        case .windowsApp, .oldGame, .consoleTool, .advanced: .wineD3D
        }
    }
}
