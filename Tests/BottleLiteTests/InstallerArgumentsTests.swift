import Foundation
import Testing

@testable import BottleLite

struct InstallerArgumentsTests {
    @Test func usesMsiexecForInstallerPackages() {
        let url = URL(filePath: "/tmp/My Installer.msi")
        #expect(BottleTooling.installerArguments(for: url) == ["msiexec", "/i", "/tmp/My Installer.msi"])
    }

    @Test func runsExecutableInstallersDirectly() {
        let url = URL(filePath: "/tmp/setup.exe")
        #expect(BottleTooling.installerArguments(for: url) == ["/tmp/setup.exe"])
    }
}
