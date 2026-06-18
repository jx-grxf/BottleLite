import Testing
@testable import BottleLite

struct WineInstallerTests {
    @Test func homebrewMissingErrorIsReadable() {
        #expect(WineInstallError.homebrewMissing.localizedDescription == "Homebrew is not installed.")
    }

    @Test func failedInstallErrorIncludesStatus() {
        #expect(WineInstallError.installationFailed(7).localizedDescription == "Homebrew exited with code 7.")
    }
}
