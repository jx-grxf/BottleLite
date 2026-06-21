import Foundation
import Testing

@testable import BottleLite

struct WineProgramRunnerTests {
    @Test func terminationMessageUsesExitStatus() {
        #expect(ProgramTermination(status: 0).message(for: "Demo") == "Demo finished.")
        #expect(ProgramTermination(status: 42).message(for: "Demo") == "Demo exited with code 42.")
    }

    @Test func steamGetsCEFGPUWorkaroundArguments() {
        let steam = URL(filePath: "/x/Steam/Steam.exe")
        let args = WineProgramRunner.injectedArguments(forExecutableAt: steam, userArguments: "")
        #expect(args.contains("-cef-disable-gpu"))
        #expect(args.contains("-cef-disable-gpu-compositing"))
    }

    @Test func nonSteamGetsNoInjectedArguments() {
        let game = URL(filePath: "/x/Game/game.exe")
        #expect(WineProgramRunner.injectedArguments(forExecutableAt: game, userArguments: "").isEmpty)
    }

    @Test func steamRespectsUserProvidedCEFFlags() {
        let steam = URL(filePath: "/x/Steam/Steam.exe")
        let args = WineProgramRunner.injectedArguments(
            forExecutableAt: steam, userArguments: "-cef-disable-gpu")
        #expect(args.isEmpty)
    }

    @Test func launchThrowsWhenExecutableMissing() {
        let runner = WineProgramRunner()
        let program = WindowsProgram(
            name: "Ghost",
            path: "/tmp/this-path-does-not-exist-\(UUID().uuidString).exe",
            validation: .valid
        )
        let bottle = Bottle(name: "Test")

        #expect(throws: ProgramRunError.executableMissing) {
            try runner.launch(program: program, bottle: bottle, winePath: "/usr/bin/true") { _ in }
        }
    }
}
