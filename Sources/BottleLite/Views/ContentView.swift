import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var store: BottleStore

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

                Button {
                    store.createBottle()
                } label: {
                    Label("New Bottle", systemImage: "plus")
                }

                Button {
                    store.isImporterPresented = true
                } label: {
                    Label("Import EXE", systemImage: "square.and.arrow.down")
                }
            }
        }
        .fileImporter(
            isPresented: $store.isImporterPresented,
            allowedContentTypes: [.exeFile],
            allowsMultipleSelection: false
        ) { result in
            guard case let .success(urls) = result, let url = urls.first else {
                return
            }
            store.importExecutable(at: url)
        }
    }
}

extension UTType {
    static let exeFile = UTType(filenameExtension: "exe") ?? .data
}
