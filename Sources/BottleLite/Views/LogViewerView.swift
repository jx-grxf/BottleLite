import AppKit
import SwiftUI

struct LogViewerView: View {
    let log: PresentedLog
    @Environment(\.dismiss) private var dismiss
    @State private var contents = "Loading log..."

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Log — \(log.title)")
                        .font(.headline)
                    Text(log.url.path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(16)

            Divider()

            ScrollView([.vertical, .horizontal]) {
                Text(contents)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            }
            .background(Color(nsColor: .textBackgroundColor))

            Divider()

            HStack {
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([log.url])
                } label: {
                    Label("Reveal in Finder", systemImage: "finder")
                }

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(contents, forType: .string)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }

                Spacer()

                Button {
                    load()
                } label: {
                    Label("Reload", systemImage: "arrow.clockwise")
                }
            }
            .controlSize(.small)
            .padding(12)
        }
        .frame(width: 640, height: 460)
        .onAppear(perform: load)
    }

    private func load() {
        let text = (try? String(contentsOf: log.url, encoding: .utf8)) ?? ""
        contents = text.isEmpty ? "The log is empty. The program produced no output yet." : text
    }
}
