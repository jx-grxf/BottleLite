import AppKit
import Foundation
import UniformTypeIdentifiers

@MainActor
final class BottleStore: ObservableObject {
    @Published var bottles: [Bottle] { didSet { persist() } }
    @Published var selection: Bottle.ID?
    @Published var runtimeStatus: RuntimeStatus = .unknown
    /// Every installed Wine binary, for the per-bottle runtime picker.
    @Published private(set) var availableRuntimes: [DetectedRuntime] = []
    @Published var isImporterPresented = false
    @Published var isInstallerImporterPresented = false
    @Published var isBottleSettingsPresented = false
    @Published var isWineInstallPromptPresented = false
    @Published var wineInstallState: WineInstallState = .idle
    @Published private(set) var isInstallingWinetricks = false
    @Published private(set) var isInstallingGamingRuntime = false
    @Published private(set) var isInstallingGPTK = false
    @Published var lastMessage = "Drop a Windows app (.exe) or installer (.msi) to begin."
    @Published var presentedLog: PresentedLog?
    @Published var installedPrograms: PresentedInstalledPrograms?
    @Published var editingProgram: PresentedProgramEditor?
    @Published var presentedFailure: PresentedProgramFailure?
    @Published private(set) var dxvkInstalling: Set<Bottle.ID> = []
    @Published private(set) var busyBottles: Set<Bottle.ID> = []
    @Published private(set) var runningPrograms: [WindowsProgram.ID: ProgramLaunch] = [:]

    private let runtimeProbe: WineRuntimeProbing
    private let programRunner: ProgramRunning
    private let wineInstaller: WineInstalling
    private let winetricksInstaller: WinetricksInstalling
    private let gamingRuntimeInstaller: GamingRuntimeInstalling
    private let repository: BottleStoring
    private let tooling: BottleToolRunning
    private var isLoaded = false
    /// Held while at least one Game Mode program is running to keep macOS from
    /// napping the app, sleeping the system, or coalescing timers.
    private var gameActivityToken: NSObjectProtocol?
    /// Retains running installer processes so their termination handlers fire
    /// (a released Process won't call back), enabling auto-scan when they exit.
    private var runningInstallers: [Process] = []

    init(
        runtimeProbe: WineRuntimeProbing = WineRuntimeProbe(),
        programRunner: ProgramRunning = WineProgramRunner(),
        wineInstaller: WineInstalling = HomebrewWineInstaller(),
        winetricksInstaller: WinetricksInstalling = HomebrewWinetricksInstaller(),
        gamingRuntimeInstaller: GamingRuntimeInstalling = HomebrewGamingRuntimeInstaller(),
        repository: BottleStoring = BottleRepository(),
        tooling: BottleToolRunning = BottleTooling()
    ) {
        self.runtimeProbe = runtimeProbe
        self.programRunner = programRunner
        self.wineInstaller = wineInstaller
        self.winetricksInstaller = winetricksInstaller
        self.gamingRuntimeInstaller = gamingRuntimeInstaller
        self.repository = repository
        self.tooling = tooling

        let stored = repository.load()
        self.bottles = stored.isEmpty ? [Bottle(name: "Default Bottle")] : stored
        self.selection = bottles.first?.id
        self.isLoaded = true
        if stored.isEmpty { persist() }

        refreshRuntime()
    }

    var selectedBottle: Bottle? {
        guard let selection else { return nil }
        return bottles.first { $0.id == selection }
    }

    var winetricksAvailable: Bool {
        tooling.winetricksPath != nil
    }

    // MARK: - Runtime

    func refreshRuntime() {
        runtimeStatus = runtimeProbe.detectRuntime()
        availableRuntimes = runtimeProbe.detectAllRuntimes()
        if runtimeStatus.state == .ready, wineInstallState.isBusy {
            wineInstallState = .idle
            lastMessage = "\(runtimeStatus.displayName) is ready."
        }
    }

    /// The Wine binary a bottle should launch with: its explicit override (when
    /// that binary still exists) else the auto-detected runtime.
    func effectiveWinePath(for bottle: Bottle) -> String? {
        if let override = bottle.winePathOverride,
            FileManager.default.isExecutableFile(atPath: override)
        {
            return override
        }
        return runtimeStatus.winePath
    }

    func wineOverride(for bottle: Bottle) -> String? {
        bottles.first { $0.id == bottle.id }?.winePathOverride
    }

    /// Sets (or clears, with `nil`) the explicit Wine runtime for a bottle.
    func setWineOverride(_ path: String?, for bottle: Bottle) {
        guard let index = bottles.firstIndex(where: { $0.id == bottle.id }) else { return }
        guard bottles[index].winePathOverride != path else { return }
        bottles[index].winePathOverride = path
        let name = bottles[index].name
        lastMessage =
            path == nil
            ? "\(name) now uses the automatic Wine runtime."
            : "\(name) will use the selected Wine. Relaunch its programs to apply."
    }

    // MARK: - Bottles

    func createBottle(named name: String = "New Bottle") {
        let uniqueName = nextAvailableName(base: name)
        let bottle = Bottle(name: uniqueName)
        bottles.insert(bottle, at: 0)
        selection = bottle.id
        lastMessage = "Created \(uniqueName)."
    }

    /// Creates a bottle from a template, pre-applying sensible Game Mode and
    /// graphics-backend defaults for that kind of app.
    func createBottle(type: BottleType) {
        let uniqueName = nextAvailableName(base: type.defaultName)
        let bottle = Bottle(
            name: uniqueName, gameMode: type.gameMode, graphicsBackend: type.graphicsBackend)
        bottles.insert(bottle, at: 0)
        selection = bottle.id
        lastMessage = "Created \(uniqueName) (\(type.title))."
    }

    /// Sets the graphics backend for a bottle and persists it.
    func setGraphicsBackend(_ backend: GraphicsBackend, for bottle: Bottle) {
        guard let index = bottles.firstIndex(where: { $0.id == bottle.id }) else { return }
        guard bottles[index].graphicsBackend != backend else { return }
        bottles[index].graphicsBackend = backend
        lastMessage =
            "Graphics set to \(backend.title) for \(bottles[index].name). Relaunch the program to apply."
    }

    func graphicsBackend(for bottle: Bottle) -> GraphicsBackend {
        bottles.first { $0.id == bottle.id }?.graphicsBackend ?? .wineD3D
    }

    func isDXVKInstalled(for bottle: Bottle) -> Bool {
        guard let prefixURL = try? BottleStorage.prefixURL(for: bottle, create: false) else {
            return false
        }
        return DXVKInstaller.isInstalled(inPrefix: prefixURL)
    }

    func isInstallingDXVK(_ bottle: Bottle) -> Bool {
        dxvkInstalling.contains(bottle.id)
    }

    /// Downloads the macOS DXVK build and installs its DLLs into the bottle so
    /// the DXVK backend has libraries to use.
    func installDXVK(for bottle: Bottle) {
        guard !dxvkInstalling.contains(bottle.id) else { return }
        // DXVK needs the arm64 MoltenVK, which a Game Porting Toolkit (x86) Wine
        // can't load — D3DMetal is the accelerated backend there. Never install
        // DXVK against a GPTK Wine.
        guard isDXVKCompatible(for: bottle) else {
            lastMessage = "DXVK can't run on this Game Porting Toolkit Wine. Use D3DMetal instead."
            return
        }
        guard
            let prefixURL = try? BottleStorage.prefixURL(for: bottle, create: false),
            FileManager.default.fileExists(atPath: prefixURL.appending(path: "drive_c").path)
        else {
            lastMessage = "Prepare \(bottle.name) first (run an app or Prepare Bottle), then install DXVK."
            return
        }

        let bottleID = bottle.id
        dxvkInstalling.insert(bottleID)
        lastMessage = "Downloading DXVK for \(bottle.name)…"
        Task {
            defer { dxvkInstalling.remove(bottleID) }
            do {
                try await DXVKInstaller.install(intoPrefix: prefixURL)
                if let index = bottles.firstIndex(where: { $0.id == bottleID }) {
                    bottles[index].graphicsBackend = .dxvk
                }
                lastMessage = "DXVK installed into \(bottle.name). Relaunch the program to use it."
            } catch {
                lastMessage = "Could not install DXVK: \(error.localizedDescription)"
            }
        }
    }

    /// winetricks verbs already installed in a bottle's prefix (from its
    /// `winetricks.log`), so the UI can show what's installed.
    func installedComponents(for bottle: Bottle) -> Set<String> {
        tooling.installedVerbs(bottle: bottle)
    }

    func renameBottle(_ bottle: Bottle, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
            let index = bottles.firstIndex(where: { $0.id == bottle.id }),
            bottles[index].name != trimmed
        else { return }

        bottles[index].name = trimmed
        lastMessage = "Renamed bottle to \(trimmed)."
    }

    /// Removes a bottle record and moves its on-disk prefix to the Trash so the
    /// action is recoverable rather than a hard delete.
    func deleteBottle(_ bottle: Bottle) {
        for program in bottle.programs where isRunning(program) {
            stop(program)
        }

        if let prefixURL = try? BottleStorage.prefixURL(for: bottle, create: false),
            FileManager.default.fileExists(atPath: prefixURL.path)
        {
            try? FileManager.default.trashItem(at: prefixURL, resultingItemURL: nil)
        }

        bottles.removeAll { $0.id == bottle.id }
        if selection == bottle.id {
            selection = bottles.first?.id
        }
        lastMessage = "Deleted \(bottle.name)."
    }

    func importExecutable(at url: URL) {
        let needsScopedAccess = url.startAccessingSecurityScopedResource()
        defer { if needsScopedAccess { url.stopAccessingSecurityScopedResource() } }

        let program = makeProgram(from: url)
        let validation = program.validation

        if bottles.isEmpty {
            createBottle(named: "Default Bottle")
        }

        let targetID = selection ?? bottles[0].id
        guard let index = bottles.firstIndex(where: { $0.id == targetID }) else {
            return
        }

        // Avoid silently importing the same executable into a bottle twice.
        guard !bottles[index].programs.contains(where: { $0.path == program.path }) else {
            selection = bottles[index].id
            lastMessage = "\(program.name) is already in \(bottles[index].name)."
            return
        }

        bottles[index].programs.insert(program, at: 0)
        selection = bottles[index].id
        lastMessage =
            validation == .valid
            ? "Imported \(program.name)."
            : "\(program.name): \(validation.label)."
    }

    func openWindowsFile(at url: URL) {
        switch url.windowsFileKind {
        case .executable:
            importExecutable(at: url)
        case .installerPackage:
            if bottles.isEmpty {
                createBottle(named: "Default Bottle")
            }
            guard let bottle = selectedBottle else {
                lastMessage = "Create a bottle before running \(url.lastPathComponent)."
                return
            }
            runInstaller(at: url, in: bottle)
        case nil:
            lastMessage = "BottleLite supports .exe and .msi files."
        }
    }

    // MARK: - Programs

    func run(_ program: WindowsProgram, in bottle: Bottle) {
        guard program.validation == .valid else {
            lastMessage = "\(program.name) is not a valid Windows executable."
            return
        }

        refreshRuntime()

        guard let winePath = effectiveWinePath(for: bottle) else {
            lastMessage = "Install Wine first, then try \(program.name) again."
            isWineInstallPromptPresented = true
            return
        }

        // Console tools have no window — run them in Terminal so output shows.
        if program.runsInTerminal {
            do {
                try tooling.runInTerminal(program: program, bottle: bottle, winePath: winePath)
                lastMessage = "Opened \(program.name) in Terminal."
            } catch {
                lastMessage = "Could not open \(program.name): \(error.localizedDescription)"
            }
            return
        }

        do {
            let launch = try programRunner.launch(
                program: program,
                bottle: bottle,
                winePath: winePath,
                gameMode: bottle.gameMode
            ) { [weak self] termination in
                Task { @MainActor in
                    self?.runningPrograms.removeValue(forKey: program.id)
                    self?.updatePowerAssertion()
                    self?.lastMessage = termination.message(for: program.name)
                    if termination.status != 0 {
                        self?.presentedFailure = PresentedProgramFailure(
                            bottleID: bottle.id,
                            programID: program.id,
                            programName: program.name,
                            exitCode: termination.status)
                    }
                }
            }

            runningPrograms[program.id] = launch
            updatePowerAssertion()
            lastMessage =
                bottle.gameMode
                ? "Started \(program.name) in Game Mode."
                : "Started \(program.name)."
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
            // Terminating the launched Process doesn't reap Wine child processes
            // (game helpers, Steam subprocesses). Hard-kill the prefix too — but
            // only if no other program from the same bottle is still running, so
            // we don't take a sibling down with it.
            if let bottle = bottles.first(where: { $0.programs.contains { $0.id == program.id } }),
                !bottle.programs.contains(where: { $0.id != program.id && runningPrograms[$0.id] != nil }),
                let winePath = effectiveWinePath(for: bottle)
            {
                tooling.terminatePrefix(bottle: bottle, winePath: winePath)
            }
            updatePowerAssertion()
            lastMessage = "Stopped \(program.name)."
        } catch {
            lastMessage = "Could not stop \(program.name): \(error.localizedDescription)"
        }
    }

    func isRunning(_ program: WindowsProgram) -> Bool {
        runningPrograms[program.id] != nil
    }

    var hasRunningPrograms: Bool {
        !runningPrograms.isEmpty
    }

    /// Stops every running program and hard-kills the affected prefixes so no
    /// Wine process is orphaned. Used by the "Stop All" command and on app quit
    /// (otherwise quitting BottleLite leaves the game running in the background).
    func terminateAllPrograms() {
        guard !runningPrograms.isEmpty else { return }

        for launch in runningPrograms.values {
            try? programRunner.stop(launch)
        }

        let activeBottles = bottles.filter { bottle in
            bottle.programs.contains { runningPrograms[$0.id] != nil }
        }
        for bottle in activeBottles {
            if let winePath = effectiveWinePath(for: bottle) {
                tooling.terminatePrefix(bottle: bottle, winePath: winePath)
            }
        }

        let count = runningPrograms.count
        runningPrograms.removeAll()
        updatePowerAssertion()
        lastMessage = count == 1 ? "Stopped 1 program." : "Stopped \(count) programs."
    }

    /// Toggles Game Mode for a bottle (performance env + power assertion on its
    /// program launches). Re-evaluates the power assertion immediately so it
    /// applies to anything already running.
    func toggleGameMode(for bottle: Bottle) {
        setGameMode(!isGameMode(bottle), for: bottle)
    }

    func setGameMode(_ enabled: Bool, for bottle: Bottle) {
        guard let index = bottles.firstIndex(where: { $0.id == bottle.id }) else { return }
        guard bottles[index].gameMode != enabled else { return }
        bottles[index].gameMode = enabled
        updatePowerAssertion()
        lastMessage =
            enabled
            ? "Game Mode on for \(bottles[index].name). Restart running programs to apply."
            : "Game Mode off for \(bottles[index].name)."
    }

    func isGameMode(_ bottle: Bottle) -> Bool {
        bottles.first { $0.id == bottle.id }?.gameMode ?? false
    }

    func editProgram(_ program: WindowsProgram, in bottle: Bottle) {
        editingProgram = PresentedProgramEditor(
            bottleID: bottle.id,
            programID: program.id,
            name: program.name,
            arguments: program.arguments,
            runsInTerminal: program.runsInTerminal
        )
    }

    /// Applies edited name/arguments back to the stored program.
    func updateProgram(
        _ programID: WindowsProgram.ID,
        in bottleID: Bottle.ID,
        name: String,
        arguments: String,
        runsInTerminal: Bool
    ) {
        guard let bottleIndex = bottles.firstIndex(where: { $0.id == bottleID }),
            let programIndex = bottles[bottleIndex].programs.firstIndex(where: { $0.id == programID })
        else { return }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty {
            bottles[bottleIndex].programs[programIndex].name = trimmedName
        }
        bottles[bottleIndex].programs[programIndex].arguments = arguments.trimmingCharacters(in: .whitespaces)
        bottles[bottleIndex].programs[programIndex].runsInTerminal = runsInTerminal
        lastMessage = "Updated \(bottles[bottleIndex].programs[programIndex].name)."
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

    /// Copies a paste-ready diagnostic report (system + Wine + bottle + last 100
    /// log lines) to the clipboard so users can file actionable GitHub issues.
    func copyDiagnosticReport(for bottle: Bottle?, program: WindowsProgram?) {
        let system = DiagnosticReport.systemInfo()
        var logLines: [String] = []
        if let bottle, let program, let logURL = existingLogURL(for: program, in: bottle) {
            logLines = DiagnosticReport.tailLines(ofFileAt: logURL, limit: 100)
        }

        let info = DiagnosticInfo(
            appVersion: Self.appVersionString,
            macOSVersion: system.macOSVersion,
            macModel: system.macModel,
            cpuArchitecture: system.cpuArchitecture,
            wineVersion: runtimeStatus.version,
            winetricksInstalled: winetricksAvailable,
            bottleName: bottle?.name,
            gameMode: bottle?.gameMode,
            programName: program?.name,
            programPath: program?.path,
            lastLogLines: logLines
        )

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(DiagnosticReport.format(info), forType: .string)
        lastMessage = "Copied a diagnostic report to the clipboard. Paste it into your GitHub issue."
    }

    private static var appVersionString: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "dev"
        let build = info?["CFBundleVersion"] as? String
        return build.map { "\(short) (\($0))" } ?? short
    }

    /// Creates a native macOS `.app` launcher for a program (with its real
    /// Windows icon) on the Desktop or in ~/Applications/BottleLite, then reveals
    /// it. Replaces the unusable `.desktop`/`.lnk` files Wine would otherwise drop.
    func createLauncher(
        for program: WindowsProgram,
        in bottle: Bottle,
        destination: ShortcutDestination
    ) {
        withWinePath(for: bottle, action: "create a launcher") { winePath in
            let appURL = try ShortcutBuilder.createLauncher(
                for: program, in: bottle, winePath: winePath, destination: destination)
            NSWorkspace.shared.activateFileViewerSelecting([appURL])
            lastMessage = "Created a launcher for \(program.name) in \(destination.directoryName)."
        }
    }

    /// Removes the Linux-style `.desktop` launchers Wine created for BottleLite
    /// bottles from the Desktop (moved to Trash, only ones we caused).
    func cleanDesktopClutter() {
        let removed = ShortcutBuilder.cleanWineDesktopClutter()
        lastMessage =
            removed == 0
            ? "No leftover Wine shortcuts on the Desktop."
            : "Moved \(removed) leftover Wine shortcut\(removed == 1 ? "" : "s") to the Trash."
    }

    /// The log file capturing a program's most recent run, if one exists.
    func existingLogURL(for program: WindowsProgram, in bottle: Bottle) -> URL? {
        guard let url = try? BottleStorage.logURL(for: program, in: bottle, create: false),
            FileManager.default.fileExists(atPath: url.path)
        else { return nil }
        return url
    }

    // MARK: - Bottle tooling

    func openConfiguration(for bottle: Bottle) {
        withWinePath(for: bottle, action: "open Wine configuration") { winePath in
            try tooling.openConfiguration(bottle: bottle, winePath: winePath)
            lastMessage = "Opening Wine configuration for \(bottle.name)..."
        }
    }

    func initializePrefix(for bottle: Bottle) {
        guard !busyBottles.contains(bottle.id) else { return }
        withWinePath(for: bottle, action: "initialize the prefix") { winePath in
            busyBottles.insert(bottle.id)
            lastMessage = "Initializing \(bottle.name)..."
            Task {
                defer { busyBottles.remove(bottle.id) }
                do {
                    try await tooling.initializePrefix(bottle: bottle, winePath: winePath)
                    lastMessage = "\(bottle.name) is ready."
                } catch {
                    lastMessage = "Could not initialize \(bottle.name): \(error.localizedDescription)"
                }
            }
        }
    }

    func isBusy(_ bottle: Bottle) -> Bool {
        busyBottles.contains(bottle.id)
    }

    /// Presents the captured log for a program if one exists on disk.
    func showLog(for program: WindowsProgram, in bottle: Bottle) {
        guard let url = existingLogURL(for: program, in: bottle) else {
            lastMessage = "No log yet for \(program.name). Run it first."
            return
        }
        presentedLog = PresentedLog(title: program.name, url: url)
    }

    func runInstaller(at url: URL, in bottle: Bottle) {
        withWinePath(for: bottle, action: "run an installer") { winePath in
            let bottleID = bottle.id
            let installerName = url.lastPathComponent
            let process = try tooling.runInstaller(at: url, bottle: bottle, winePath: winePath) {
                [weak self] status in
                Task { @MainActor in
                    self?.installerDidFinish(bottleID: bottleID, name: installerName, status: status)
                }
            }
            runningInstallers.append(process)
            lastMessage = "Running \(installerName) in \(bottle.name)..."
        }
    }

    /// Called when an installer process exits: drops the retained process and
    /// auto-scans the prefix so the user immediately sees what was installed.
    private func installerDidFinish(bottleID: Bottle.ID, name: String, status: Int32) {
        runningInstallers.removeAll { !$0.isRunning }
        guard let bottle = bottles.first(where: { $0.id == bottleID }) else { return }
        presentInstalledPrograms(for: bottle)
        if installedPrograms != nil {
            lastMessage = "\(name) finished. Pick the app it installed to add it to \(bottle.name)."
        }
    }

    func installDependency(_ verb: WinetricksVerb, in bottle: Bottle) {
        withWinePath(for: bottle, action: "install \(verb.title)") { winePath in
            try tooling.installDependency(verb, bottle: bottle, winePath: winePath)
            lastMessage = "Installing \(verb.title) into \(bottle.name)..."
        }
    }

    func revealDriveC(for bottle: Bottle) {
        guard let driveC = try? BottleStorage.driveCURL(for: bottle, create: false) else { return }
        if !FileManager.default.fileExists(atPath: driveC.path) {
            lastMessage = "Initialize \(bottle.name) first to create its C: drive."
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([driveC])
        lastMessage = "Revealed the C: drive for \(bottle.name)."
    }

    // MARK: - Steam

    @Published private(set) var isInstallingSteam = false

    /// One-click Steam: ensure a dedicated "Steam" bottle exists, download the
    /// official SteamSetup.exe, and run it (auto-scan kicks in when it finishes).
    func installSteam() {
        guard !isInstallingSteam else { return }

        refreshRuntime()
        guard runtimeStatus.winePath != nil else {
            lastMessage = "Install Wine first, then install Steam."
            isWineInstallPromptPresented = true
            return
        }

        // The modern Steam client only runs on a gaming-grade (GPTK /
        // CrossOver-lineage) Wine — plain wine-stable crash-loops. Install that
        // prerequisite first instead of downloading Steam into a Wine that
        // can't run it.
        guard isGamingWineInstalled else {
            lastMessage =
                "Steam needs a gaming-grade Wine (Game Porting Toolkit). Opening its installer first…"
            Task { await installGamePortingToolkit() }
            return
        }

        // Reuse an existing Steam bottle, otherwise create one from the tuned
        // Steam template (Game Mode + fastest available graphics) — a bare
        // wineD3D bottle can't run the modern Steam client well.
        let bottle =
            bottles.first { $0.name == "Steam" }
            ?? {
                createBottle(type: .steamGame); return selectedBottle
            }()
        guard let bottle else { return }
        selection = bottle.id

        isInstallingSteam = true
        lastMessage = "Downloading Steam…"
        Task {
            defer { isInstallingSteam = false }
            do {
                let installer = try await SteamInstaller.downloadSetup()
                runInstaller(at: installer, in: bottle)
            } catch {
                lastMessage = "Could not download Steam: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Installed programs

    /// Scans the bottle's prefix for installed executables and presents them so
    /// the user can add the actual game/app after an installer has run.
    func presentInstalledPrograms(for bottle: Bottle) {
        guard let driveC = try? BottleStorage.driveCURL(for: bottle, create: false),
            FileManager.default.fileExists(atPath: driveC.path)
        else {
            lastMessage = "Initialize \(bottle.name) and run an installer first."
            return
        }
        let candidates = InstalledProgramScanner.scan(bottle: bottle)
        installedPrograms = PresentedInstalledPrograms(
            bottleID: bottle.id,
            bottleName: bottle.name,
            candidates: candidates
        )
    }

    /// Adds an executable that already exists inside the prefix (or anywhere on
    /// disk) as a program in the given bottle.
    @discardableResult
    func addProgram(at url: URL, to bottleID: Bottle.ID) -> Bool {
        guard let index = bottles.firstIndex(where: { $0.id == bottleID }) else { return false }
        let name = url.deletingPathExtension().lastPathComponent

        guard !bottles[index].programs.contains(where: { $0.path == url.path }) else {
            lastMessage = "\(name) is already in \(bottles[index].name)."
            return false
        }

        let program = makeProgram(from: url)
        bottles[index].programs.insert(program, at: 0)
        selection = bottleID
        lastMessage = "Added \(name) to \(bottles[index].name)."
        return true
    }

    func isProgramAdded(_ url: URL, in bottleID: Bottle.ID) -> Bool {
        bottles.first { $0.id == bottleID }?.programs.contains { $0.path == url.path } ?? false
    }

    /// Opens an Open panel rooted at the bottle's C: drive so the user can pick an
    /// installed executable the scanner missed.
    func browseForInstalledProgram(in bottle: Bottle) {
        guard let driveC = try? BottleStorage.driveCURL(for: bottle, create: false),
            FileManager.default.fileExists(atPath: driveC.path)
        else {
            lastMessage = "Initialize \(bottle.name) and run an installer first."
            return
        }

        let panel = NSOpenPanel()
        panel.directoryURL = driveC
        panel.allowedContentTypes = [.windowsExecutable]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.prompt = "Add"
        panel.message = "Choose the installed .exe inside \(bottle.name)"

        if panel.runModal() == .OK, let url = panel.url {
            addProgram(at: url, to: bottle.id)
        }
    }

    // MARK: - Wine install

    func promptWineInstall() {
        isWineInstallPromptPresented = true
    }

    /// Whether MoltenVK (the Vulkan→Metal layer DXVK needs) is installed.
    var isGamingRuntimeInstalled: Bool { GamingRuntime.isMoltenVKInstalled }

    /// Installs MoltenVK + the Vulkan loader via Homebrew in Terminal so DXVK can
    /// actually run games.
    func installGamingRuntime() async {
        guard !isInstallingGamingRuntime else { return }

        isInstallingGamingRuntime = true
        lastMessage = "Opening gaming-runtime installer in Terminal…"
        defer { isInstallingGamingRuntime = false }

        do {
            try await gamingRuntimeInstaller.openInstaller()
            lastMessage = "Finish the Terminal installer, then set a bottle's Graphics to DXVK."
        } catch {
            lastMessage = "Gaming runtime install failed: \(error.localizedDescription)"
        }
    }

    var isGPTKInstalled: Bool { GraphicsBackend.isD3DMetalAvailable }

    /// Whether a gaming-grade Wine (GPTK / CrossOver lineage) is present. Plain
    /// Homebrew `wine-stable` can't run the modern Steam client; this can.
    var isGamingWineInstalled: Bool { GamingRuntime.isGamingWineInstalled }

    /// Whether DXVK can actually run on a bottle's effective Wine. False for a
    /// Game Porting Toolkit (x86) Wine, where the arm64 MoltenVK can't be loaded
    /// — there, D3DMetal is the backend to use instead. Bottle-aware because the
    /// runtime can be overridden per bottle.
    func isDXVKCompatible(for bottle: Bottle) -> Bool {
        guard let path = effectiveWinePath(for: bottle) else { return true }
        return !GamingRuntime.isGPTKWine(path)
    }

    /// Installs Gcenx's Game Porting Toolkit (D3DMetal / DirectX 12) in Terminal.
    func installGamePortingToolkit() async {
        guard !isInstallingGPTK else { return }

        isInstallingGPTK = true
        lastMessage = "Opening Game Porting Toolkit installer in Terminal…"
        defer { isInstallingGPTK = false }

        do {
            try await HomebrewGPTKInstaller().openInstaller()
            lastMessage = "Finish the Terminal installer, then choose D3DMetal."
        } catch {
            lastMessage = "Game Porting Toolkit install failed: \(error.localizedDescription)"
        }
    }

    /// Opens a Terminal that installs winetricks via Homebrew, then re-checks
    /// availability so the dependency menu unlocks once it lands.
    func installWinetricks() async {
        guard !isInstallingWinetricks, !winetricksAvailable else { return }

        isInstallingWinetricks = true
        lastMessage = "Opening winetricks installer in Terminal..."
        defer { isInstallingWinetricks = false }

        do {
            try await winetricksInstaller.openInstaller()
            lastMessage = "Finish the Terminal installer, then reopen the dependency menu."
        } catch {
            lastMessage = "winetricks install failed: \(error.localizedDescription)"
        }
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
            lastMessage = "\(runtimeStatus.displayName) is ready."
        } else {
            wineInstallState = .failed(
                "Wine is still missing. Finish the Terminal installer, then check again.")
            lastMessage = "Wine is still missing."
        }
    }

    // MARK: - Helpers

    private func withWinePath(for bottle: Bottle? = nil, action: String, _ body: (String) throws -> Void) {
        refreshRuntime()
        let resolved = bottle.flatMap { effectiveWinePath(for: $0) } ?? runtimeStatus.winePath
        guard let winePath = resolved else {
            lastMessage = "Install Wine first to \(action)."
            isWineInstallPromptPresented = true
            return
        }
        do {
            try body(winePath)
        } catch {
            lastMessage = "Could not \(action): \(error.localizedDescription)"
        }
    }

    private func persist() {
        guard isLoaded else { return }
        repository.save(bottles)
    }

    private func makeProgram(from url: URL) -> WindowsProgram {
        let validation = ExecutableInspector.validate(url)
        let subsystem = validation == .valid ? ExecutableInspector.subsystem(of: url) : .unknown

        return WindowsProgram(
            name: url.deletingPathExtension().lastPathComponent,
            path: url.path,
            validation: validation,
            runsInTerminal: subsystem == .console
        )
    }

    /// Begins or ends the macOS activity assertion based on whether any running
    /// program belongs to a Game Mode bottle.
    private func updatePowerAssertion() {
        let gameModeBottleIDs = Set(bottles.filter(\.gameMode).map(\.id))
        let needsAssertion =
            bottles
            .filter { gameModeBottleIDs.contains($0.id) }
            .flatMap(\.programs)
            .contains { runningPrograms[$0.id] != nil }

        if needsAssertion, gameActivityToken == nil {
            gameActivityToken = ProcessInfo.processInfo.beginActivity(
                options: [.userInitiated, .idleSystemSleepDisabled, .latencyCritical],
                reason: "BottleLite Game Mode"
            )
        } else if !needsAssertion, let token = gameActivityToken {
            ProcessInfo.processInfo.endActivity(token)
            gameActivityToken = nil
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

/// Identifies a log file to present in the log viewer sheet.
struct PresentedLog: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let url: URL
}

/// Backs the "Add Installed Program" sheet: the bottle plus the executables the
/// scanner found inside its prefix.
struct PresentedInstalledPrograms: Identifiable, Equatable {
    let id = UUID()
    let bottleID: Bottle.ID
    let bottleName: String
    let candidates: [FoundExecutable]
}

/// Backs the "a program exited with an error" helper sheet.
struct PresentedProgramFailure: Identifiable, Equatable {
    let id = UUID()
    let bottleID: Bottle.ID
    let programID: WindowsProgram.ID
    let programName: String
    let exitCode: Int32
}

/// Backs the program settings sheet (rename + launch arguments).
struct PresentedProgramEditor: Identifiable, Equatable {
    let id = UUID()
    let bottleID: Bottle.ID
    let programID: WindowsProgram.ID
    var name: String
    var arguments: String
    var runsInTerminal: Bool
}
