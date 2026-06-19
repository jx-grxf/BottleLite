import SwiftUI

/// Lists executables discovered inside a bottle's prefix so the user can add the
/// installed game/app after running its installer.
struct InstalledProgramsPickerView: View {
    let presented: PresentedInstalledPrograms
    @ObservedObject var store: BottleStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            if presented.candidates.isEmpty {
                emptyState
            } else {
                List(presented.candidates) { candidate in
                    row(for: candidate)
                }
                .listStyle(.inset)
            }

            Divider()

            footer
        }
        .frame(width: 560, height: 440)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Add Installed Program")
                .font(.headline)
            Text("Found in the C: drive of \(presented.bottleName)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
    }

    private func row(for candidate: FoundExecutable) -> some View {
        let added = store.isProgramAdded(candidate.url, in: presented.bottleID)
        return HStack(spacing: 12) {
            Image(systemName: "app.dashed")
                .foregroundStyle(.tint)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text(candidate.name)
                    .font(.body.weight(.medium))
                Text(candidate.displayPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Button {
                store.addProgram(at: candidate.url, to: presented.bottleID)
            } label: {
                Label(added ? "Added" : "Add", systemImage: added ? "checkmark" : "plus")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(added)
        }
        .padding(.vertical, 4)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Installed Programs Found", systemImage: "magnifyingglass")
        } description: {
            Text("Run the game's installer first, then scan again — or browse the C: drive manually.")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack {
            Button {
                store.browseForInstalledProgram(in: bottle)
            } label: {
                Label("Browse C: Drive…", systemImage: "folder")
            }
            .controlSize(.small)

            Spacer()

            Button("Done") { dismiss() }
                .keyboardShortcut(.defaultAction)
        }
        .padding(12)
    }

    /// Reconstruct a lightweight Bottle reference for the manual-browse panel.
    private var bottle: Bottle {
        store.bottles.first { $0.id == presented.bottleID }
            ?? Bottle(id: presented.bottleID, name: presented.bottleName)
    }
}
