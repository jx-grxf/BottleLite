import Foundation
import Testing

@testable import BottleLite

struct ProgramArgumentsTests {
    @Test func splitsPlainArguments() {
        #expect(WineProgramRunner.parseArguments("-fullscreen -w 800") == ["-fullscreen", "-w", "800"])
    }

    @Test func honorsQuotedValuesWithSpaces() {
        #expect(
            WineProgramRunner.parseArguments("-config \"My Game/cfg.ini\"")
                == ["-config", "My Game/cfg.ini"]
        )
    }

    @Test func collapsesExtraWhitespaceAndEmpty() {
        #expect(WineProgramRunner.parseArguments("   ") == [])
        #expect(WineProgramRunner.parseArguments("a   b") == ["a", "b"])
    }

    @Test func programDecodesWithoutArgumentsKey() throws {
        let json = """
            {
              "id": "\(UUID().uuidString)",
              "name": "Game",
              "path": "/x/game.exe",
              "importedAt": "2026-01-01T00:00:00Z",
              "validation": "valid"
            }
            """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let program = try decoder.decode(WindowsProgram.self, from: Data(json.utf8))
        #expect(program.arguments.isEmpty)
        #expect(program.runsInTerminal == false)
        #expect(program.name == "Game")
    }
}
