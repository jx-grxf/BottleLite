import Foundation
import Testing

@testable import BottleLite

struct GameModeTests {
    @Test func gameModeEnvironmentEnablesPerformanceFlags() {
        let env = WineProgramRunner.gameModeEnvironment
        #expect(env["WINEMSYNC"] == "1")
        #expect(env["WINEESYNC"] == "1")
        #expect(env["MTL_HUD_ENABLED"] == "1")
    }

    @Test func largeAddressAwareSkippedOnGPTKWine() {
        // GPTK (Wow64) Wine crashes 32-bit games with alloc_pages_vprot when
        // WINE_LARGE_ADDRESS_AWARE is set, so Game Mode must omit it there.
        let gptk = WineProgramRunner.wineEnvironment(
            prefixPath: "/tmp/p", winePath: GamingRuntime.gptkAppWine64, gameMode: true,
            graphicsBackend: .wineD3D)
        #expect(gptk["WINE_LARGE_ADDRESS_AWARE"] == nil)
        #expect(gptk["WINEMSYNC"] == "1")

        // On a plain Wine it's safe and helps older 32-bit titles.
        let plain = WineProgramRunner.wineEnvironment(
            prefixPath: "/tmp/p", winePath: "/opt/homebrew/bin/wine", gameMode: true,
            graphicsBackend: .wineD3D)
        #expect(plain["WINE_LARGE_ADDRESS_AWARE"] == "1")
    }

    @Test func bottleDecodesWithoutGameModeKey() throws {
        let json = """
            {
              "id": "\(UUID().uuidString)",
              "name": "Legacy",
              "createdAt": "2026-01-01T00:00:00Z",
              "programs": []
            }
            """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let bottle = try decoder.decode(Bottle.self, from: Data(json.utf8))
        #expect(bottle.name == "Legacy")
        #expect(bottle.gameMode == false)
        // Pre-override bottles must default to the automatic runtime.
        #expect(bottle.winePathOverride == nil)
    }

    @Test func winePathOverridePersistsThroughRepository() {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "wo-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }

        let repository = BottleRepository(fileURLOverride: url)
        repository.save([Bottle(name: "Old game", winePathOverride: "/opt/homebrew/bin/wine")])
        #expect(repository.load().first?.winePathOverride == "/opt/homebrew/bin/wine")
    }

    @Test func gameModePersistsThroughRepository() {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "gm-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }

        let repository = BottleRepository(fileURLOverride: url)
        repository.save([Bottle(name: "Game", gameMode: true)])
        #expect(repository.load().first?.gameMode == true)
    }
}
