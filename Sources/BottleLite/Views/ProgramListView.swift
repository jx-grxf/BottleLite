import SwiftUI

struct ProgramListView: View {
    let bottle: Bottle
    @ObservedObject var store: BottleStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Programs")
                .font(.headline)

            if bottle.programs.isEmpty {
                EmptyProgramsView()
            } else {
                VStack(spacing: 8) {
                    ForEach(bottle.programs) { program in
                        ProgramRowView(
                            program: program,
                            isRunning: store.isRunning(program),
                            canRun: store.runtimeStatus.state == .ready && program.validation == .valid
                        )
                        .environmentObject(store)
                        .environment(\.bottle, bottle)
                    }
                }
            }
        }
    }
}

private struct EmptyProgramsView: View {
    var body: some View {
        ContentUnavailableView(
            "No Programs Yet",
            systemImage: "rectangle.dashed.badge.record",
            description: Text("Import an .exe to start shaping this bottle.")
        )
        .frame(maxWidth: .infinity, minHeight: 180)
    }
}

private struct ProgramRowView: View {
    let program: WindowsProgram
    let isRunning: Bool
    let canRun: Bool
    @EnvironmentObject private var store: BottleStore
    @Environment(\.bottle) private var bottle

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: program.validation == .valid ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(program.validation == .valid ? .green : .orange)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text(program.name)
                    .font(.body.weight(.medium))
                Text(program.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Button {
                if isRunning {
                    store.stop(program)
                } else if let bottle {
                    store.run(program, in: bottle)
                }
            } label: {
                Label(isRunning ? "Stop" : "Run", systemImage: isRunning ? "stop.fill" : "play.fill")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(!isRunning && !canRun)
            .help(isRunning ? "Stop this program" : "Run with Wine")

            Menu {
                Button {
                    store.revealInFinder(program)
                } label: {
                    Label("Reveal in Finder", systemImage: "finder")
                }

                Button {
                    store.copyPath(program)
                } label: {
                    Label("Copy Path", systemImage: "doc.on.doc")
                }

                Divider()

                Button(role: .destructive) {
                    if let bottle {
                        store.remove(program, from: bottle)
                    }
                } label: {
                    Label("Remove", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.button)
            .buttonStyle(.borderless)
            .help("Program actions")

            Text(program.validation.label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(.quaternary, in: Capsule())
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contextMenu {
            if isRunning {
                Button {
                    store.stop(program)
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
            } else if let bottle {
                Button {
                    store.run(program, in: bottle)
                } label: {
                    Label("Run", systemImage: "play.fill")
                }
                .disabled(!canRun)
            }

            Button {
                store.revealInFinder(program)
            } label: {
                Label("Reveal in Finder", systemImage: "finder")
            }

            Button {
                store.copyPath(program)
            } label: {
                Label("Copy Path", systemImage: "doc.on.doc")
            }

            Divider()

            Button(role: .destructive) {
                if let bottle {
                    store.remove(program, from: bottle)
                }
            } label: {
                Label("Remove", systemImage: "trash")
            }
        }
    }
}

private struct BottleEnvironmentKey: EnvironmentKey {
    static let defaultValue: Bottle? = nil
}

private extension EnvironmentValues {
    var bottle: Bottle? {
        get { self[BottleEnvironmentKey.self] }
        set { self[BottleEnvironmentKey.self] = newValue }
    }
}
