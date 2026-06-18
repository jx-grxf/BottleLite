import AppKit
import Foundation

@MainActor
final class BottleStore: ObservableObject {
    @Published var bottles: [Bottle]
    @Published var selection: Bottle.ID?
    @Published var runtimeStatus: RuntimeStatus = .unknown
    @Published var isImporterPresented = false
    @Published var isWineInstallPromptPresented = false
    @Published var wineInstallState: WineInstallState = .idle
    @Published var lastMessage = "Drop an .exe to begin."
    @Published private(set) var runningPrograms: [WindowsProgram.ID: ProgramLaunch] = [:]

    private let runtimeProbe: WineRuntimeProbing
    private let programRunner: ProgramRunning
    private let wineInstaller: WineInstalling

    init(
        runtimeProbe: WineRuntimeProbing = WineRuntimeProbe(),
        programRunner: ProgramRunning = WineProgramRunner(),
        wineInstaller: WineInstalling = HomebrewWineInstaller()
    ) {
        self.runtimeProbe = runtimeProbe
        self.programRunner = programRunner
        self.wineInstaller = wineInstaller
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
        if runtimeStatus.state == .ready, wineInstallState.isBusy {
            wineInstallState = .idle
            lastMessage = "Wine runtime detected."
        }
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

    func run(_ program: WindowsProgram, in bottle: Bottle) {
        guard program.validation == .valid else {
            lastMessage = "\(program.name) is not a valid Windows executable."
            return
        }

        refreshRuntime()

        guard let winePath = runtimeStatus.winePath else {
            lastMessage = "Install Wine first, then try \(program.name) again."
            isWineInstallPromptPresented = true
            return
        }

        do {
            let launch = try programRunner.launch(
                program: program,
                bottle: bottle,
                winePath: winePath
            ) { [weak self] termination in
                Task { @MainActor in
                    self?.runningPrograms.removeValue(forKey: program.id)
                    self?.lastMessage = termination.message(for: program.name)
                }
            }

            runningPrograms[program.id] = launch
            lastMessage = "Started \(program.name) with pid \(launch.processID)."
        } catch {
            runningPrograms.removeValue(forKey: program.id)
            lastMessage = "Could not start \(program.name): \(error.localizedDescription)"
        }
    }

    func stop(_ program: WindowsProgram) {
        guard let launch = runningPrograms[program.id] else {
            lastMessage = "\(program.name) is not running."
            return
        }

        do {
            try programRunner.stop(launch)
            runningPrograms.removeValue(forKey: program.id)
            lastMessage = "Stopped \(program.name)."
        } catch {
            lastMessage = "Could not stop \(program.name): \(error.localizedDescription)"
        }
    }

    func isRunning(_ program: WindowsProgram) -> Bool {
        runningPrograms[program.id] != nil
    }

    func remove(_ program: WindowsProgram, from bottle: Bottle) {
        if isRunning(program) {
            stop(program)
        }

        guard let bottleIndex = bottles.firstIndex(where: { $0.id == bottle.id }) else {
            return
        }

        bottles[bottleIndex].programs.removeAll { $0.id == program.id }
        lastMessage = "Removed \(program.name) from \(bottle.name)."
    }

    func revealInFinder(_ program: WindowsProgram) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(filePath: program.path)])
        lastMessage = "Revealed \(program.name) in Finder."
    }

    func copyPath(_ program: WindowsProgram) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(program.path, forType: .string)
        lastMessage = "Copied \(program.name) path."
    }

    func promptWineInstall() {
        isWineInstallPromptPresented = true
    }

    func installWine() async {
        guard !wineInstallState.isBusy else { return }

        wineInstallState = .installing
        lastMessage = "Opening Wine installer in Terminal..."

        do {
            try await wineInstaller.openInstaller()
            wineInstallState = .waitingForTerminal
            lastMessage = "Finish the Terminal installer, then click Check Again."
        } catch {
            wineInstallState = .failed(error.localizedDescription)
            lastMessage = "Wine install failed: \(error.localizedDescription)"
        }
    }

    func checkWineInstall() {
        refreshRuntime()

        if runtimeStatus.state == .ready {
            wineInstallState = .idle
            lastMessage = "Wine runtime detected."
        } else {
            wineInstallState = .failed("Wine is still missing. Finish the Terminal installer, then check again.")
            lastMessage = "Wine is still missing."
        }
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
