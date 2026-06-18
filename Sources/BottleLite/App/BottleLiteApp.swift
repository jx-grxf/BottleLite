import AppKit
import SwiftUI

@main
struct BottleLiteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = BottleStore()

    var body: some Scene {
        WindowGroup("BottleLite", id: "main") {
            ContentView(store: store)
                .frame(minWidth: 920, minHeight: 560)
        }
        .commands {
            SidebarCommands()
            CommandGroup(replacing: .newItem) {
                Button("Import Windows Executable...") {
                    store.isImporterPresented = true
                }
                .keyboardShortcut("o", modifiers: [.command])
            }
        }

        Settings {
            SettingsView(store: store)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}
