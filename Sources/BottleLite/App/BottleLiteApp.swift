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
                .onAppear { appDelegate.store = store }
        }
        .commands {
            SidebarCommands()

            CommandGroup(replacing: .newItem) {
                Button("New Bottle") {
                    store.createBottle()
                }
                .keyboardShortcut("n", modifiers: [.command])

                Button("Import Windows Executable...") {
                    store.isImporterPresented = true
                }
                .keyboardShortcut("o", modifiers: [.command])
            }

            CommandGroup(after: .toolbar) {
                Button("Refresh Wine Runtime") {
                    store.refreshRuntime()
                }
                .keyboardShortcut("r", modifiers: [.command])

                Button("Stop All Programs") {
                    store.terminateAllPrograms()
                }
                .keyboardShortcut(".", modifiers: [.command, .shift])
                .disabled(!store.hasRunningPrograms)
            }

            CommandGroup(replacing: .help) {
                Link("BottleLite on GitHub", destination: Self.repositoryURL)
                Link("Report an Issue", destination: Self.issuesURL)
            }
        }

        Settings {
            SettingsView(store: store)
        }
    }

    static let repositoryURL = URL(string: "https://github.com/jx-grxf/BottleLite")!
    static let issuesURL = URL(string: "https://github.com/jx-grxf/BottleLite/issues")!
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var store: BottleStore?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    // Quitting BottleLite must also tear down any Wine processes it started,
    // otherwise the game keeps running in the background after the app is gone.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        store?.terminateAllPrograms()
        return .terminateNow
    }
}
