import SwiftUI

struct SidebarView: View {
    @ObservedObject var store: BottleStore

    @State private var renameTarget: Bottle?
    @State private var renameText = ""
    @State private var deleteTarget: Bottle?

    var body: some View {
        List(selection: $store.selection) {
            Section("Bottles") {
                ForEach(store.bottles) { bottle in
                    BottleRowView(
                        bottle: bottle,
                        runningCount: runningCount(in: bottle)
                    )
                    .tag(bottle.id)
                    .contextMenu {
                        contextMenu(for: bottle)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("BottleLite")
        .overlay {
            if store.bottles.isEmpty {
                ContentUnavailableView(
                    "No Bottles",
                    systemImage: "shippingbox",
                    description: Text("Create a bottle to get started.")
                )
            }
        }
        .alert("Rename Bottle", isPresented: renameBinding) {
            TextField("Bottle name", text: $renameText)
            Button("Cancel", role: .cancel) { renameTarget = nil }
            Button("Rename") {
                if let renameTarget {
                    store.renameBottle(renameTarget, to: renameText)
                }
                renameTarget = nil
            }
        }
        .confirmationDialog(
            deleteTarget.map { "Delete “\($0.name)”?" } ?? "Delete bottle?",
            isPresented: deleteBinding,
            titleVisibility: .visible
        ) {
            Button("Move Files to Trash", role: .destructive) {
                if let deleteTarget {
                    store.deleteBottle(deleteTarget)
                }
                deleteTarget = nil
            }
            Button("Cancel", role: .cancel) { deleteTarget = nil }
        } message: {
            Text("The bottle and its Wine prefix will be moved to the Trash.")
        }
    }

    @ViewBuilder
    private func contextMenu(for bottle: Bottle) -> some View {
        Button {
            renameText = bottle.name
            renameTarget = bottle
        } label: {
            Label("Rename…", systemImage: "pencil")
        }

        Button {
            store.revealDriveC(for: bottle)
        } label: {
            Label("Reveal C: Drive", systemImage: "externaldrive")
        }

        Divider()

        Button(role: .destructive) {
            deleteTarget = bottle
        } label: {
            Label("Delete…", systemImage: "trash")
        }
    }

    private func runningCount(in bottle: Bottle) -> Int {
        bottle.programs.reduce(into: 0) { count, program in
            if store.isRunning(program) { count += 1 }
        }
    }

    private var renameBinding: Binding<Bool> {
        Binding(get: { renameTarget != nil }, set: { if !$0 { renameTarget = nil } })
    }

    private var deleteBinding: Binding<Bool> {
        Binding(get: { deleteTarget != nil }, set: { if !$0 { deleteTarget = nil } })
    }
}

private struct BottleRowView: View {
    let bottle: Bottle
    let runningCount: Int

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(bottle.name)
                    .font(.body)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(runningCount > 0 ? Color.green : .secondary)
            }
        } icon: {
            Image(systemName: runningCount > 0 ? "shippingbox.fill" : "shippingbox")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(runningCount > 0 ? Color.green : .primary)
        }
        .padding(.vertical, 3)
    }

    private var subtitle: String {
        let programs = "\(bottle.programs.count) program\(bottle.programs.count == 1 ? "" : "s")"
        return runningCount > 0 ? "\(programs) · \(runningCount) running" : programs
    }
}
