import Testing
@testable import BottleLite

struct WineInstallerTests {
    @Test func homebrewMissingErrorIsReadable() {
        #expect(WineInstallError.homebrewMissing.localizedDescription == "Homebrew is not installed.")
    }

    @Test func terminalOpenErrorIsReadable() {
        #expect(WineInstallError.terminalOpenFailed.localizedDescription == "Could not open Terminal.")
    }
}
