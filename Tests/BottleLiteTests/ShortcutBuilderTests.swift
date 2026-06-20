import Foundation
import Testing

@testable import BottleLite

struct ShortcutBuilderTests {
    @Test func sanitizesUnsafeNames() {
        #expect(ShortcutBuilder.sanitizedAppName("  Note/pad:++  ") == "Note-pad-++")
        #expect(ShortcutBuilder.sanitizedAppName("   ") == "Windows App")
        #expect(ShortcutBuilder.sanitizedAppName("Game") == "Game")
    }

    @Test func launchScriptWiresPrefixWineAndDisablesMenuBuilder() {
        let program = WindowsProgram(
            name: "Game", path: "/tmp/My Game/game.exe", validation: .valid, arguments: "-fullscreen")
        let script = ShortcutBuilder.launchScript(
            program: program, prefixPath: "/tmp/prefix", winePath: "/opt/homebrew/bin/wine")

        #expect(script.contains("export WINEPREFIX='/tmp/prefix'"))
        #expect(script.contains("winemenubuilder.exe=d"))
        #expect(script.contains("'/opt/homebrew/bin/wine' '/tmp/My Game/game.exe' '-fullscreen'"))
        #expect(script.contains("cd '/tmp/My Game'"))
        #expect(script.hasPrefix("#!/bin/zsh"))
    }
}
