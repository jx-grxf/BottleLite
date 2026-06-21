import SwiftUI

/// Shown when a program exits with an error. Instead of a cryptic status line, it
/// explains likely causes and offers one-tap fixes (graphics backend, common
/// runtimes, the log, and a diagnostic report).
struct ProgramFailureView: View {
    @ObservedObject var store: BottleStore
    let failure: PresentedProgramFailure
    @Environment(\.dismiss) private var dismiss

    private var bottle: Bottle? { store.bottles.first { $0.id == failure.bottleID } }
    private var program: WindowsProgram? { bottle?.programs.first { $0.id == failure.programID } }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            reasons
            Divider()
            fixes
        }
        .padding(24)
        .frame(width: 470)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title)
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 3) {
                Text("\(failure.programName) didn't run properly")
                    .font(.headline)
                Text("It exited with code \(failure.exitCode). These are the usual causes:")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var reasons: some View {
        VStack(alignment: .leading, spacing: 6) {
            reason("Missing Visual C++ or .NET runtime")
            reason("Missing DirectX components")
            reason("The game needs a faster graphics layer (DXVK / D3DMetal)")
            reason("Kernel-level anti-cheat (not supported on macOS)")
        }
        .font(.callout)
    }

    private var fixes: some View {
        VStack(spacing: 8) {
            if !store.isGamingWineInstalled {
                fixButton(
                    "gamecontroller.fill", "Install gaming-grade Wine (recommended)",
                    "Steam's client and modern games need a CrossOver-lineage Wine + D3DMetal, "
                        + "not plain Wine. This is the actual fix."
                ) {
                    Task { await store.installGamePortingToolkit() }
                }
            }
            if let bottle, store.graphicsBackend(for: bottle) != .dxvk {
                fixButton(
                    "bolt.fill", "Try DXVK graphics",
                    "Download DXVK and switch this bottle to it."
                ) {
                    store.installDXVK(for: bottle)
                }
            }
            if let bottle, let vc = verb("vcrun2022") {
                fixButton("shippingbox", "Install \(vc.title)", vc.detail) {
                    store.installDependency(vc, in: bottle)
                }
            }
            if let bottle, let dx = verb("d3dx9") {
                fixButton("shippingbox", "Install \(dx.title)", dx.detail) {
                    store.installDependency(dx, in: bottle)
                }
            }
            if let bottle, let program,
                store.existingLogURL(for: program, in: bottle) != nil
            {
                fixButton("doc.text.magnifyingglass", "Open Log", "See what Wine reported.") {
                    store.showLog(for: program, in: bottle)
                }
            }
            fixButton(
                "stethoscope", "Copy Diagnostic Report",
                "Copy details to paste into a GitHub issue."
            ) {
                store.copyDiagnosticReport(for: bottle, program: program)
            }

            HStack {
                Spacer()
                Button("Close") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Helpers

    private func reason(_ text: String) -> some View {
        Label(text, systemImage: "circle.fill")
            .labelStyle(BulletLabelStyle())
            .foregroundStyle(.secondary)
    }

    private func fixButton(
        _ symbol: String, _ title: String, _ detail: String, perform: @escaping () -> Void
    ) -> some View {
        Button {
            perform()
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: symbol).frame(width: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.callout.weight(.medium))
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func verb(_ id: String) -> WinetricksVerb? {
        WinetricksVerb.common.first { $0.verb == id }
    }
}

/// A tiny bullet "•" leading a label, for the reasons list.
private struct BulletLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("•")
            configuration.title
        }
    }
}
