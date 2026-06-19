import Foundation
import Testing

@testable import BottleLite

struct GameModeTests {
    @Test func gameModeEnvironmentEnablesPerformanceFlags() {
        let env = WineProgramRunner.gameModeEnvironment
        #expect(env["WINEMSYNC"] == "1")
        #expect(env["WINEESYNC"] == "1")
        #expect(env["WINE_LARGE_ADDRESS_AWARE"] == "1")
        #expect(env["MTL_HUD_ENABLED"] == "1")
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
