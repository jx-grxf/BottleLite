import SwiftUI
import UniformTypeIdentifiers

struct BottleDetailView: View {
    @ObservedObject var store: BottleStore

    var body: some View {
        VStack(spacing: 0) {
            HeaderView(store: store)

            Divider()

            if let bottle = store.selectedBottle {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        DropZoneView(store: store)
                        ProgramListView(bottle: bottle, store: store)
                    }
                    .padding(24)
                }
            } else {
                ContentUnavailableView(
                    "No Bottle Selected",
                    systemImage: "shippingbox",
                    description: Text("Create a bottle or select one from the sidebar.")
                )
            }
        }
        .navigationTitle(store.selectedBottle?.name ?? "BottleLite")
        .toolbar {
            if let bottle = store.selectedBottle {
                ToolbarItem(placement: .primaryAction) {
                    BottleActionsMenu(store: store, bottle: bottle)
                }
            }
        }
        .alert("Install Wine?", isPresented: $store.isWineInstallPromptPresented) {
            Button("Cancel", role: .cancel) {}
            Button("Install Wine") {
                Task { await store.installWine() }
            }
        } message: {
            Text("BottleLite can install Wine using Homebrew so Windows executables can be launched.")
        }
        .fileImporter(
            isPresented: $store.isInstallerImporterPresented,
            allowedContentTypes: [.exeFile],
            allowsMultipleSelection: false
        ) { result in
            guard
                case let .success(urls) = result,
                let url = urls.first,
                let bottle = store.selectedBottle
            else { return }
            store.runInstaller(at: url, in: bottle)
        }
        .sheet(item: $store.presentedLog) { log in
            LogViewerView(log: log)
        }
        .sheet(item: $store.installedPrograms) { presented in
            InstalledProgramsPickerView(presented: presented, store: store)
        }
        .sheet(item: $store.editingProgram) { editor in
            ProgramSettingsView(editor: editor, store: store)
        }
    }
}

private struct BottleActionsMenu: View {
    @ObservedObject var store: BottleStore
    let bottle: Bottle

    var body: some View {
        Menu {
            Toggle(isOn: gameModeBinding) {
                Label("Game Mode", systemImage: "gamecontroller")
            }
            .help("Extra performance: msync/esync, high priority, no idle sleep, Metal FPS overlay")

            Divider()

            Button {
                store.isInstallerImporterPresented = true
            } label: {
                Label("Run Installer…", systemImage: "arrow.down.app")
            }

            Button {
                store.presentInstalledPrograms(for: bottle)
            } label: {
                Label("Add Installed Program…", systemImage: "plus.app")
            }

            Button {
                store.openConfiguration(for: bottle)
            } label: {
                Label("Wine Configuration", systemImage: "gearshape")
            }

            Button {
                store.initializePrefix(for: bottle)
            } label: {
                Label("Initialize Prefix", systemImage: "wand.and.stars")
            }
            .disabled(store.isBusy(bottle))

            Divider()

            dependenciesMenu

            Divider()

            Button {
                store.revealDriveC(for: bottle)
            } label: {
                Label("Reveal C: Drive", systemImage: "externaldrive")
            }
        } label: {
            Label("Bottle Actions", systemImage: "slider.horizontal.3")
        }
        .menuIndicator(.visible)
        .help("Configure and manage this bottle")
    }

    private var gameModeBinding: Binding<Bool> {
        Binding(
            get: { store.isGameMode(bottle) },
            set: { store.setGameMode($0, for: bottle) }
        )
    }

    @ViewBuilder
    private var dependenciesMenu: some View {
        if store.winetricksAvailable {
            Menu {
                ForEach(WinetricksVerb.common) { verb in
                    Button(verb.title) {
                        store.installDependency(verb, in: bottle)
                    }
                }
            } label: {
                Label("Install Dependency", systemImage: "shippingbox.and.arrow.backward")
            }
        } else {
            Button {
                store.lastMessage = "Install winetricks first: brew install winetricks"
            } label: {
                Label("Install Dependency (needs winetricks)", systemImage: "shippingbox.and.arrow.backward")
            }
        }
    }
}

private struct HeaderView: View {
    @ObservedObject var store: BottleStore

    var body: some View {
        HStack(spacing: 14) {
            RuntimeStatusView(status: store.runtimeStatus)

            if store.runtimeStatus.state == .missing {
                if store.wineInstallState == .installing {
                    ProgressView()
                        .controlSize(.small)
                        .progressViewStyle(.circular)
                }

                Button {
                    if store.wineInstallState == .waitingForTerminal {
                        store.checkWineInstall()
                    } else {
                        store.promptWineInstall()
                    }
                } label: {
                    Label(buttonTitle, systemImage: buttonIcon)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(store.wineInstallState == .installing)
            }

            Spacer()

            if store.selectedBottle?.gameMode == true {
                Label("Game Mode", systemImage: "gamecontroller.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(.green.opacity(0.15), in: Capsule())
            }

            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(.regularMaterial)
    }

    private var message: String {
        switch store.wineInstallState {
        case .idle:
            store.lastMessage
        case .installing:
            "Opening Terminal installer..."
        case .waitingForTerminal:
            "Finish Wine install in Terminal, then check again."
        case let .failed(error):
            error
        }
    }

    private var buttonTitle: String {
        store.wineInstallState == .waitingForTerminal ? "Check Again" : "Install Wine"
    }

    private var buttonIcon: String {
        store.wineInstallState == .waitingForTerminal ? "checkmark.circle" : "terminal"
    }
}
