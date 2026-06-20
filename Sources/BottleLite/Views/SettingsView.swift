import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: BottleStore
    @ObservedObject var updates: UpdateService
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        Form {
            Section("Wine Runtime") {
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
                LabeledContent("winetricks", value: store.winetricksAvailable ? "Installed" : "Not installed")

                Button("Refresh Now") {
                    store.refreshRuntime()
                }
            }

            Section("Updates") {
                LabeledContent("Installed", value: Self.appVersion)

                if updates.isUpdateAvailable, let available = updates.availableUpdateVersion {
                    LabeledContent("Available") {
                        Label(available, systemImage: "arrow.down.circle.fill")
                    }
                }

                Picker("Channel", selection: $updates.channel) {
                    ForEach(UpdateService.Channel.allCases) { channel in
                        Text(channel.displayName).tag(channel)
                    }
                }
                .pickerStyle(.segmented)

                Toggle("Check automatically", isOn: automaticChecksBinding)

                if let date = updates.lastCheckDate {
                    LabeledContent("Last check", value: date.formatted(date: .abbreviated, time: .shortened))
                }

                Button("Check Now") {
                    updates.checkForUpdates()
                }
                .disabled(!updates.canCheckForUpdates)
            }

            Section("Storage") {
                Button("Reveal Bottle Data in Finder") {
                    if let url = try? BottleStorage.supportDirectory() {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    }
                }
            }

            Section("Diagnostics") {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Diagnostic Report")
                        Text(
                            "Copies your macOS, Mac, Wine and bottle details to the clipboard for GitHub issues."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Button("Copy") {
                        store.copyDiagnosticReport(for: store.selectedBottle, program: nil)
                    }
                }
            }

            Section("Help") {
                Button("Show Welcome Screen Again") {
                    hasCompletedOnboarding = false
                }
            }

            Section("About") {
                Link("BottleLite on GitHub", destination: BottleLiteApp.repositoryURL)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
    }

    private static var appVersion: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "dev"
        let build = info?["CFBundleVersion"] as? String
        return build.map { "\(short) (\($0))" } ?? short
    }

    private var automaticChecksBinding: Binding<Bool> {
        Binding(
            get: { updates.automaticallyChecksForUpdates },
            set: { updates.automaticallyChecksForUpdates = $0 }
        )
    }
}
