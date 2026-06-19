import SwiftUI

struct ProgramListView: View {
    let bottle: Bottle
    @ObservedObject var store: BottleStore
    @State private var query = ""

    private var filteredPrograms: [WindowsProgram] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return bottle.programs }
        return bottle.programs.filter {
            $0.name.localizedCaseInsensitiveContains(trimmed)
                || $0.path.localizedCaseInsensitiveContains(trimmed)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Programs")
                    .font(.headline)
                if !bottle.programs.isEmpty {
                    Text("\(bottle.programs.count)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: Capsule())
                }
                Spacer()
                if bottle.programs.count > 3 {
                    searchField
                }
            }

            if bottle.programs.isEmpty {
                EmptyProgramsView()
            } else if filteredPrograms.isEmpty {
                ContentUnavailableView.search(text: query)
                    .frame(maxWidth: .infinity, minHeight: 140)
            } else {
                VStack(spacing: 8) {
                    ForEach(filteredPrograms) { program in
                        ProgramRowView(
                            program: program,
                            isRunning: store.isRunning(program),
                            canRun: store.runtimeStatus.state == .ready && program.validation == .valid,
                            hasLog: store.existingLogURL(for: program, in: bottle) != nil
                        )
                        .environmentObject(store)
                        .environment(\.bottle, bottle)
                    }
                }
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 5) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.caption)
            TextField("Filter", text: $query)
                .textFieldStyle(.plain)
                .frame(width: 130)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.quaternary, in: Capsule())
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
    let hasLog: Bool
    @EnvironmentObject private var store: BottleStore
    @Environment(\.bottle) private var bottle

    var body: some View {
        HStack(spacing: 12) {
            statusIcon

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(program.name)
                        .font(.body.weight(.medium))
                    if isRunning {
                        Text("Running")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.green)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(.green.opacity(0.15), in: Capsule())
                    }
                }
                Text(program.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if !program.arguments.isEmpty {
                    Label(program.arguments, systemImage: "terminal")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                if program.runsInTerminal {
                    Label("Runs in Terminal", systemImage: "terminal")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text(
                    "Added \(DateFormatters.relative.localizedString(for: program.importedAt, relativeTo: .now))"
                )
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }

            Spacer()

            runButton
            actionsMenu

            Text(program.validation.label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(.quaternary, in: Capsule())
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contextMenu { contextMenuItems }
    }

    private var statusIcon: some View {
        Image(
            systemName: program.validation == .valid ? "checkmark.seal.fill" : "exclamationmark.triangle.fill"
        )
        .foregroundStyle(program.validation == .valid ? .green : .orange)
        .font(.title3)
    }

    private var runButton: some View {
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
    }

    private var actionsMenu: some View {
        Menu {
            if let bottle {
                Button {
                    store.editProgram(program, in: bottle)
                } label: {
                    Label("Program Settings…", systemImage: "slider.horizontal.3")
                }
                Divider()
            }

            if hasLog, let bottle {
                Button {
                    store.showLog(for: program, in: bottle)
                } label: {
                    Label("View Log", systemImage: "doc.text.magnifyingglass")
                }
                Divider()
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
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .menuStyle(.button)
        .buttonStyle(.borderless)
        .help("Program actions")
    }

    @ViewBuilder
    private var contextMenuItems: some View {
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

        if hasLog, let bottle {
            Button {
                store.showLog(for: program, in: bottle)
            } label: {
                Label("View Log", systemImage: "doc.text.magnifyingglass")
            }
        }

        if let bottle {
            Button {
                store.editProgram(program, in: bottle)
            } label: {
                Label("Program Settings…", systemImage: "slider.horizontal.3")
            }
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

private struct BottleEnvironmentKey: EnvironmentKey {
    static let defaultValue: Bottle? = nil
}

private extension EnvironmentValues {
    var bottle: Bottle? {
        get { self[BottleEnvironmentKey.self] }
        set { self[BottleEnvironmentKey.self] = newValue }
    }
}
