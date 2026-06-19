import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: BottleStore
    @AppStorage("autoRefreshRuntime") private var autoRefreshRuntime = true

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

                Toggle("Refresh runtime status on launch", isOn: $autoRefreshRuntime)

                Button("Refresh Now") {
                    store.refreshRuntime()
                }
            }

            Section("Storage") {
                Button("Reveal Bottle Data in Finder") {
                    if let url = try? BottleStorage.supportDirectory() {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    }
                }
            }

            Section("About") {
                LabeledContent("Version", value: Self.appVersion)
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
}
