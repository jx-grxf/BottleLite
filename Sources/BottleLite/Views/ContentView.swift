import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var store: BottleStore
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showWelcome = false

    var body: some View {
        NavigationSplitView {
            SidebarView(store: store)
        } detail: {
            BottleDetailView(store: store)
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    store.refreshRuntime()
                } label: {
                    Label("Refresh Runtime", systemImage: "arrow.clockwise")
                }
                .help("Re-check which Wine runtime is installed")

                Button {
                    store.createBottle()
                } label: {
                    Label("New Bottle", systemImage: "plus")
                }
                .help("Create a new isolated Windows environment")

                Button {
                    store.isImporterPresented = true
                } label: {
                    Label("Add Windows App", systemImage: "square.and.arrow.down")
                }
                .help("Add a Windows app (.exe) or installer (.msi) to the selected bottle")
            }
        }
        .fileImporter(
            isPresented: $store.isImporterPresented,
            allowedContentTypes: UTType.importableWindowsFileTypes,
            allowsMultipleSelection: false
        ) { result in
            guard case let .success(urls) = result, let url = urls.first else {
                return
            }
            store.openWindowsFile(at: url)
        }
        .sheet(isPresented: $showWelcome) {
            WelcomeView(store: store)
        }
        .task {
            if !hasCompletedOnboarding { showWelcome = true }
        }
        .onChange(of: hasCompletedOnboarding) { _, completed in
            if !completed { showWelcome = true }
        }
    }
}
