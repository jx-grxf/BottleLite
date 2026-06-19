import SwiftUI

/// Edits a program's display name and launch arguments.
struct ProgramSettingsView: View {
    let editor: PresentedProgramEditor
    @ObservedObject var store: BottleStore
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var arguments: String
    @State private var runsInTerminal: Bool

    init(editor: PresentedProgramEditor, store: BottleStore) {
        self.editor = editor
        self.store = store
        _name = State(initialValue: editor.name)
        _arguments = State(initialValue: editor.arguments)
        _runsInTerminal = State(initialValue: editor.runsInTerminal)
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Program") {
                    TextField("Name", text: $name)
                }

                Section("Launch Arguments") {
                    TextField("e.g. -fullscreen --windowed", text: $arguments)
                        .font(.body.monospaced())
                    Text("Passed to the executable after its path. Quote values with spaces.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Console Tools") {
                    Toggle("Run in Terminal", isOn: $runsInTerminal)
                    Text("Use this for command-line .exe tools so stdout, stderr, and prompts are visible.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    store.updateProgram(
                        editor.programID,
                        in: editor.bottleID,
                        name: name,
                        arguments: arguments,
                        runsInTerminal: runsInTerminal
                    )
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(12)
        }
        .frame(width: 460, height: 390)
    }
}
