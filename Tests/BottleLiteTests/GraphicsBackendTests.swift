import Foundation
import Testing

@testable import BottleLite

struct GraphicsBackendTests {
    @Test func builtInBackendHasNoOverrides() {
        #expect(GraphicsBackend.wineD3D.dllOverrides == nil)
        #expect(GraphicsBackend.dxvk.dllOverrides?.contains("d3d11=n,b") == true)
        #expect(GraphicsBackend.d3dMetal.dllOverrides?.contains("dxgi") == true)
    }

    @Test func launchOverridesAlwaysDisableMenuBuilder() {
        #expect(WineProgramRunner.dllOverrides(for: .wineD3D) == "winemenubuilder.exe=d")

        let dxvk = WineProgramRunner.dllOverrides(for: .dxvk)
        #expect(dxvk.contains("winemenubuilder.exe=d"))
        #expect(dxvk.contains("dxgi,d3d9,d3d10core,d3d11=n,b"))
    }

    @Test func bottleDecodesWithoutGraphicsBackendKey() throws {
        let json = """
            {"id":"\(UUID().uuidString)","name":"Legacy","createdAt":"2026-01-01T00:00:00Z"}
            """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let bottle = try decoder.decode(Bottle.self, from: Data(json.utf8))
        #expect(bottle.graphicsBackend == .wineD3D)
    }

    @Test func steamTemplateUsesGamingDefaults() {
        #expect(BottleType.steamGame.gameMode == true)
        #expect(BottleType.steamGame.graphicsBackend == .dxvk)
        #expect(BottleType.windowsApp.graphicsBackend == .wineD3D)
    }
}
