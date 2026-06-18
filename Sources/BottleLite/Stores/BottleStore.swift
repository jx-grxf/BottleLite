import Foundation

@MainActor
final class BottleStore: ObservableObject {
    @Published var bottles: [Bottle]
    @Published var selection: Bottle.ID?
    @Published var runtimeStatus: RuntimeStatus = .unknown
    @Published var isImporterPresented = false
    @Published var lastMessage = "Drop an .exe to begin."

    private let runtimeProbe: WineRuntimeProbing

    init(runtimeProbe: WineRuntimeProbing = WineRuntimeProbe()) {
        self.runtimeProbe = runtimeProbe
        self.bottles = [
            Bottle(
                name: "Default Bottle",
                programs: []
            )
        ]
        self.selection = bottles.first?.id
        refreshRuntime()
    }

    var selectedBottle: Bottle? {
        guard let selection else { return nil }
        return bottles.first { $0.id == selection }
    }

    func refreshRuntime() {
        runtimeStatus = runtimeProbe.detectRuntime()
    }

    func createBottle(named name: String = "New Bottle") {
        let uniqueName = nextAvailableName(base: name)
        let bottle = Bottle(name: uniqueName)
        bottles.insert(bottle, at: 0)
        selection = bottle.id
        lastMessage = "Created \(uniqueName)."
    }

    func importExecutable(at url: URL) {
        let validation = ExecutableInspector.validate(url)
        let program = WindowsProgram(
            name: url.deletingPathExtension().lastPathComponent,
            path: url.path,
            validation: validation
        )

        if bottles.isEmpty {
            createBottle(named: "Default Bottle")
        }

        let targetID = selection ?? bottles[0].id
        guard let index = bottles.firstIndex(where: { $0.id == targetID }) else {
            return
        }

        bottles[index].programs.insert(program, at: 0)
        selection = bottles[index].id
        lastMessage = validation == .valid
            ? "Imported \(program.name)."
            : "\(program.name): \(validation.label)."
    }

    private func nextAvailableName(base: String) -> String {
        let existing = Set(bottles.map(\.name))
        guard existing.contains(base) else { return base }

        var suffix = 2
        while existing.contains("\(base) \(suffix)") {
            suffix += 1
        }
        return "\(base) \(suffix)"
    }
}
