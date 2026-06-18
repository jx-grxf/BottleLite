import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: BottleStore
    @AppStorage("autoRefreshRuntime") private var autoRefreshRuntime = true

    var body: some View {
        Form {
            Toggle("Refresh Wine runtime status on launch", isOn: $autoRefreshRuntime)

            Button("Refresh Now") {
                store.refreshRuntime()
            }
        }
        .formStyle(.grouped)
        .padding(24)
        .frame(width: 420)
    }
}
