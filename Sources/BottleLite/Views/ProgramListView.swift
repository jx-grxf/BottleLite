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
                        ) {
                            store.run(program, in: bottle)
                        }
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
    let run: () -> Void

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
                run()
            } label: {
                Label(isRunning ? "Running" : "Run", systemImage: isRunning ? "hourglass" : "play.fill")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(!canRun || isRunning)
            .help(canRun ? "Run with Wine" : "Install Wine before running this program")

            Text(program.validation.label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(.quaternary, in: Capsule())
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
