import Foundation
import Testing
@testable import BottleLite

struct WineProgramRunnerTests {
    @Test func terminationMessageUsesExitStatus() {
        #expect(ProgramTermination(status: 0).message(for: "Demo") == "Demo finished.")
        #expect(ProgramTermination(status: 42).message(for: "Demo") == "Demo exited with code 42.")
    }
}
