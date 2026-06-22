import Testing

@testable import BottleLite

struct RuntimeStatusTests {
    @Test func displayNameUsesVersionWhenPresent() {
        let status = RuntimeStatus(state: .ready, message: "Ready", winePath: "/x/wine", version: "Wine 10.0")
        #expect(status.displayName == "Wine 10.0")
    }

    @Test func displayNameFallsBackToMessage() {
        let status = RuntimeStatus(
            state: .missing, message: "No Wine runtime found yet.", winePath: nil, version: nil)
        #expect(status.displayName == "No Wine runtime found yet.")
    }

    @Test func unknownStatusHasNoPath() {
        #expect(RuntimeStatus.unknown.winePath == nil)
        #expect(RuntimeStatus.unknown.state == .unknown)
    }
}

struct DetectedRuntimeTests {
    @Test func labelPrefersVersionString() {
        let withVersion = DetectedRuntime(path: "/x/bin/wine64", version: "Wine 9.0")
        #expect(withVersion.label == "Wine 9.0")
    }

    @Test func labelFallsBackToBundleNameWhenVersionMissing() {
        let runtime = DetectedRuntime(
            path: "/Applications/Wine Stable.app/Contents/Resources/wine/bin/wine64", version: nil)
        #expect(!runtime.label.isEmpty)
        #expect(runtime.label != "/Applications/Wine Stable.app/Contents/Resources/wine/bin/wine64")
    }

    @Test func detectsGPTKPath() {
        #expect(DetectedRuntime(path: GamingRuntime.gptkAppWine64, version: nil).isGPTK)
        #expect(!DetectedRuntime(path: "/opt/homebrew/bin/wine", version: nil).isGPTK)
    }
}

struct WinetricksVerbTests {
    @Test func commonVerbsAreUniqueAndNonEmpty() {
        let verbs = WinetricksVerb.common
        #expect(!verbs.isEmpty)
        #expect(Set(verbs.map(\.id)).count == verbs.count)
        #expect(verbs.allSatisfy { !$0.title.isEmpty })
    }
}
