import AppKit
import SwiftUI

/// App-level preferences, organized into tabs like a standard macOS Settings
/// window. Per-bottle options live in `BottleSettingsView`; this is for things
/// that span the whole app — the Wine runtime, the gaming libraries, updates.
struct SettingsView: View {
    @ObservedObject var store: BottleStore
    @ObservedObject var updates: UpdateService

    var body: some View {
        TabView {
            GeneralSettingsTab(store: store)
                .tabItem { Label("General", systemImage: "gearshape") }
            RuntimeSettingsTab(store: store)
                .tabItem { Label("Runtime", systemImage: "cpu") }
            UpdatesSettingsTab(updates: updates)
                .tabItem { Label("Updates", systemImage: "arrow.triangle.2.circlepath") }
            AboutSettingsTab(store: store)
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 520, height: 460)
    }
}

// MARK: - General

private struct GeneralSettingsTab: View {
    @ObservedObject var store: BottleStore
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        Form {
            Section("Storage") {
                settingRow(
                    "Bottle Data",
                    "Where BottleLite keeps each bottle's Windows C: drive and programs.",
                    action: "Reveal in Finder"
                ) {
                    if let url = try? BottleStorage.supportDirectory() {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    }
                }
            }

            Section("Onboarding") {
                settingRow(
                    "Welcome Screen",
                    "Show the first-run setup again the next time you open BottleLite.",
                    action: "Show Again"
                ) {
                    hasCompletedOnboarding = false
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Runtime

private struct RuntimeSettingsTab: View {
    @ObservedObject var store: BottleStore

    var body: some View {
        Form {
            Section {
                LabeledContent("Status", value: store.runtimeStatus.displayName)
                if let path = store.runtimeStatus.winePath {
                    LabeledContent("Path") {
                        Text(path)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                Button("Refresh Now") { store.refreshRuntime() }
            } header: {
                Text("Wine")
            } footer: {
                Text("BottleLite prefers a gaming-grade Wine (Game Porting Toolkit) when present.")
            }

            Section {
                installRow(
                    "MoltenVK",
                    "Vulkan → Metal. Lets the DXVK backend run DirectX 9–11 games.",
                    installed: store.isGamingRuntimeInstalled,
                    busy: store.isInstallingGamingRuntime
                ) {
                    Task { await store.installGamingRuntime() }
                }

                installRow(
                    "Game Porting Toolkit",
                    "CrossOver-lineage Wine + D3DMetal (DirectX 11/12 → Metal). Needed for "
                        + "the Steam client and modern games.",
                    installed: store.isGPTKInstalled,
                    busy: store.isInstallingGPTK
                ) {
                    Task { await store.installGamePortingToolkit() }
                }

                LabeledContent(
                    "winetricks", value: store.winetricksAvailable ? "Installed" : "Not installed")
            } header: {
                Text("Gaming Libraries")
            } footer: {
                Text("Installed once for your whole Mac, then used by any bottle.")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Updates

private struct UpdatesSettingsTab: View {
    @ObservedObject var updates: UpdateService

    var body: some View {
        Form {
            Section("Version") {
                LabeledContent("Installed", value: SettingsView.appVersion)
                if updates.isUpdateAvailable, let available = updates.availableUpdateVersion {
                    LabeledContent("Available") {
                        Label(available, systemImage: "arrow.down.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
            }

            Section("Automatic Updates") {
                Picker("Channel", selection: $updates.channel) {
                    ForEach(UpdateService.Channel.allCases) { channel in
                        Text(channel.displayName).tag(channel)
                    }
                }
                .pickerStyle(.segmented)

                Toggle("Check automatically", isOn: automaticChecksBinding)

                if let date = updates.lastCheckDate {
                    LabeledContent(
                        "Last check",
                        value: date.formatted(date: .abbreviated, time: .shortened))
                }

                Button("Check Now") { updates.checkForUpdates() }
                    .disabled(!updates.canCheckForUpdates)
            }
        }
        .formStyle(.grouped)
    }

    private var automaticChecksBinding: Binding<Bool> {
        Binding(
            get: { updates.automaticallyChecksForUpdates },
            set: { updates.automaticallyChecksForUpdates = $0 }
        )
    }
}

// MARK: - About

private struct AboutSettingsTab: View {
    @ObservedObject var store: BottleStore

    var body: some View {
        Form {
            Section {
                LabeledContent("BottleLite", value: SettingsView.appVersion)
                Link("BottleLite on GitHub", destination: BottleLiteApp.repositoryURL)
                Link("Report an Issue", destination: BottleLiteApp.issuesURL)
            }

            Section {
                settingRow(
                    "Diagnostic Report",
                    "Copies your macOS, Mac, Wine and bottle details to the clipboard for issues.",
                    action: "Copy"
                ) {
                    store.copyDiagnosticReport(for: store.selectedBottle, program: nil)
                }
            } header: {
                Text("Diagnostics")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Shared helpers

extension SettingsView {
    static var appVersion: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "dev"
        let build = info?["CFBundleVersion"] as? String
        return build.map { "\(short) (\($0))" } ?? short
    }
}

/// A titled row with a description and a trailing action button.
private func settingRow(
    _ title: String, _ detail: String, action: String, perform: @escaping () -> Void
) -> some View {
    HStack(alignment: .firstTextBaseline) {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        Spacer()
        Button(action, action: perform)
    }
}

/// A row that shows an install state: a green "Installed" badge, a spinner, or
/// an Install button.
@MainActor
private func installRow(
    _ title: String, _ detail: String, installed: Bool, busy: Bool,
    install: @escaping () -> Void
) -> some View {
    HStack(alignment: .firstTextBaseline) {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        Spacer()
        if busy {
            ProgressView().controlSize(.small)
        } else if installed {
            Label("Installed", systemImage: "checkmark.circle.fill")
                .labelStyle(.titleAndIcon)
                .foregroundStyle(.green)
                .font(.caption.weight(.medium))
        } else {
            Button("Install…", action: install)
        }
    }
}
