import Foundation
import Testing

@testable import BottleLite

struct WineProgramRunnerTests {
    @Test func terminationMessageUsesExitStatus() {
        #expect(ProgramTermination(status: 0).message(for: "Demo") == "Demo finished.")
        #expect(ProgramTermination(status: 42).message(for: "Demo") == "Demo exited with code 42.")
    }

    @Test func steamGetsGPTKWorkaroundArgumentsOnceBootstrapped() throws {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory.appending(path: "BL-steam-\(UUID().uuidString)")
        try fm.createDirectory(at: dir.appending(path: "bin/cef"), withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: dir) }

        let steam = dir.appending(path: "Steam.exe")
        let args = WineProgramRunner.injectedArguments(forExecutableAt: steam, userArguments: "")
        #expect(args.contains("-allosarches"))
        #expect(args.contains("-cef-force-32bit"))
    }

    @Test func steamGetsNoArgumentsBeforeBootstrap() throws {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory.appending(path: "BL-steam-\(UUID().uuidString)")
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: dir) }

        // No `bin/cef` yet → the 32-bit-CEF workaround must not be applied, so it
        // can't block the first bootstrap.
        let steam = dir.appending(path: "Steam.exe")
        #expect(WineProgramRunner.injectedArguments(forExecutableAt: steam, userArguments: "").isEmpty)
    }

    @Test func nonSteamGetsNoInjectedArguments() {
        let game = URL(filePath: "/x/Game/game.exe")
        #expect(WineProgramRunner.injectedArguments(forExecutableAt: game, userArguments: "").isEmpty)
    }

    @Test func steamRespectsUserProvidedCEFFlags() {
        let steam = URL(filePath: "/x/Steam/Steam.exe")
        #expect(
            WineProgramRunner.injectedArguments(forExecutableAt: steam, userArguments: "-cef-force-32bit")
                .isEmpty)
        #expect(
            WineProgramRunner.injectedArguments(forExecutableAt: steam, userArguments: "-allosarches")
                .isEmpty)
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
