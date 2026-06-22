import SwiftUI

/// Per-bottle settings, presented as a sheet. Replaces the old flat actions
/// menu: every control sits in a labelled section with a one-line explanation so
/// it's clear what each one does.
struct BottleSettingsView: View {
    @ObservedObject var store: BottleStore
    let bottle: Bottle
    @Environment(\.dismiss) private var dismiss
    @State private var installed: Set<String> = []

    var body: some View {
        VStack(spacing: 0) {
            Form {
                runtimeSection
                performanceSection
                graphicsSection
                componentsSection
                setupSection
                maintenanceSection
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .frame(width: 460, height: 560)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(bottle.name).font(.headline)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
        .task { installed = store.installedComponents(for: bottle) }
    }

    // MARK: - Graphics

    private var graphicsSection: some View {
        Section {
            Picker("DirectX Backend", selection: graphicsBinding) {
                ForEach(GraphicsBackend.allCases) { backend in
                    Text(backend.title).tag(backend)
                }
            }
            description(store.graphicsBackend(for: bottle).detail)

            if store.graphicsBackend(for: bottle) == .dxvk, !store.isDXVKCompatible(for: bottle) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("DXVK can't run on this Wine build")
                        description(
                            "Game Porting Toolkit Wine is x86 and can't load the arm64 MoltenVK. "
                                + "Switch this bottle to D3DMetal for accelerated graphics.")
                    }
                    Spacer()
                    Button("Use D3DMetal") {
                        store.setGraphicsBackend(.d3dMetal, for: bottle)
                    }
                }
            }

            if store.graphicsBackend(for: bottle) == .dxvk, store.isDXVKCompatible(for: bottle) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("MoltenVK (system)")
                        description("Vulkan → Metal. Needed once on your Mac for DXVK to work.")
                    }
                    Spacer()
                    if store.isInstallingGamingRuntime {
                        ProgressView().controlSize(.small)
                    } else if store.isGamingRuntimeInstalled {
                        Label("Installed", systemImage: "checkmark.circle.fill")
                            .labelStyle(.titleAndIcon)
                            .foregroundStyle(.green)
                            .font(.caption.weight(.medium))
                    } else {
                        Button("Install") { Task { await store.installGamingRuntime() } }
                    }
                }

                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("DXVK libraries (this bottle)")
                        description("The DirectX→Vulkan DLLs, installed per bottle.")
                    }
                    Spacer()
                    if store.isInstallingDXVK(bottle) {
                        ProgressView().controlSize(.small)
                    } else if store.isDXVKInstalled(for: bottle) {
                        Label("Installed", systemImage: "checkmark.circle.fill")
                            .labelStyle(.titleAndIcon)
                            .foregroundStyle(.green)
                            .font(.caption.weight(.medium))
                    } else {
                        Button("Install") { store.installDXVK(for: bottle) }
                    }
                }
            }

            if store.graphicsBackend(for: bottle) == .d3dMetal, !GraphicsBackend.isD3DMetalAvailable {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Game Porting Toolkit")
                        description(
                            "Not detected. D3DMetal needs Apple's GPTK (a large, advanced install). "
                                + "Until then this falls back to the built-in renderer.")
                    }
                    Spacer()
                    if store.isInstallingGPTK {
                        ProgressView().controlSize(.small)
                    } else {
                        Button("Install…") { Task { await store.installGamePortingToolkit() } }
                    }
                }
            }
        } header: {
            Text("Graphics")
        } footer: {
            Text("Applies the next time you launch a program in this bottle.")
        }
    }

    // MARK: - Wine runtime

    private var runtimeSection: some View {
        Section {
            Picker("Wine Runtime", selection: wineBinding) {
                Text("Automatic").tag(String?.none)
                ForEach(store.availableRuntimes) { runtime in
                    Text(runtime.label).tag(String?.some(runtime.path))
                }
            }
            description(
                "Most bottles should stay Automatic (the gaming-grade Game Porting Toolkit). "
                    + "But GPTK can't run some 32-bit / OpenGL games — pick a plain Wine for those.")

            if !store.availableRuntimes.contains(where: { !$0.isGPTK }) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("No plain Wine installed")
                        description(
                            "Only Game Porting Toolkit is detected. Install a plain Wine to run "
                                + "32-bit games like AssaultCube, then select it above.")
                    }
                    Spacer()
                    Button("Install…") { Task { await store.installWine() } }
                        .disabled(store.wineInstallState.isBusy)
                }
            }
        } header: {
            Text("Wine Runtime")
        } footer: {
            Text("Applies the next time you launch a program in this bottle.")
        }
    }

    // MARK: - Performance

    private var performanceSection: some View {
        Section("Performance") {
            Toggle(isOn: gameModeBinding) {
                Text("Game Mode")
                description(
                    "Extra speed for games: msync/esync, high priority, no idle sleep, "
                        + "and the Metal FPS overlay. Restart a running game to apply.")
            }
        }
    }

    // MARK: - Windows components (winetricks)

    private var componentsSection: some View {
        Section {
            if store.winetricksAvailable {
                ForEach(WinetricksVerb.common) { verb in
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verb.title)
                            description(verb.detail)
                        }
                        Spacer()
                        if installed.contains(verb.verb) {
                            Menu {
                                Button("Reinstall") { store.installDependency(verb, in: bottle) }
                            } label: {
                                Label("Installed", systemImage: "checkmark.circle.fill")
                                    .labelStyle(.titleAndIcon)
                                    .foregroundStyle(.green)
                                    .font(.caption.weight(.medium))
                            }
                            .menuStyle(.borderlessButton)
                            .fixedSize()
                        } else {
                            Button("Add") { store.installDependency(verb, in: bottle) }
                        }
                    }
                }
            } else {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("winetricks isn't installed yet")
                        description(
                            "winetricks adds Windows pieces some apps need (fonts, Visual C++, "
                                + ".NET, DirectX). BottleLite installs it via Homebrew in Terminal.")
                    }
                    Spacer()
                    Button("Install…") { Task { await store.installWinetricks() } }
                        .disabled(store.isInstallingWinetricks)
                }
            }
        } header: {
            Text("Windows Components")
        } footer: {
            Text(
                "Only add what a game or app needs. Windows components can't be cleanly uninstalled — "
                    + "create a fresh bottle to start clean.")
        }
    }

    // MARK: - Setup

    private var setupSection: some View {
        Section("Setup") {
            settingRow(
                "Prepare Bottle",
                "One-time setup of the Windows C: drive. Usually happens automatically.",
                action: "Prepare", disabled: store.isBusy(bottle)
            ) {
                store.initializePrefix(for: bottle)
            }
            settingRow(
                "Wine Configuration",
                "Opens Wine's own settings (winecfg) for advanced tweaks."
            ) {
                store.openConfiguration(for: bottle)
            }
        }
    }

    // MARK: - Maintenance

    private var maintenanceSection: some View {
        Section("Maintenance") {
            settingRow(
                "Reveal C: Drive",
                "Open the bottle's virtual Windows C: drive in Finder."
            ) {
                store.revealDriveC(for: bottle)
            }
            settingRow(
                "Clean Up Desktop Shortcuts",
                "Move leftover Wine .desktop/.lnk shortcut files for this app off your Desktop."
            ) {
                store.cleanDesktopClutter()
            }
        }
    }

    // MARK: - Helpers

    private var gameModeBinding: Binding<Bool> {
        Binding(
            get: { store.isGameMode(bottle) },
            set: { store.setGameMode($0, for: bottle) }
        )
    }

    private var wineBinding: Binding<String?> {
        Binding(
            get: { store.wineOverride(for: bottle) },
            set: { store.setWineOverride($0, for: bottle) }
        )
    }

    private var graphicsBinding: Binding<GraphicsBackend> {
        Binding(
            get: { store.graphicsBackend(for: bottle) },
            set: { store.setGraphicsBackend($0, for: bottle) }
        )
    }

    private func description(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func settingRow(
        _ title: String,
        _ detail: String,
        action: String = "Open",
        disabled: Bool = false,
        perform: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                description(detail)
            }
            Spacer()
            Button(action, action: perform)
                .disabled(disabled)
        }
    }
}
