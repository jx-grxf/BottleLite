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
        } header: {
            Text("Graphics")
        } footer: {
            Text(
                "Applies the next time you launch a program. Full speedups also need the backend's "
                    + "libraries (the DXVK component below, or a Game Porting Toolkit Wine build).")
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
