import SwiftUI

/// First-run wizard: a friendly welcome, a quick system check, and three clear
/// starting points. Shown once (gated by the `hasCompletedOnboarding` flag).
struct WelcomeView: View {
    @ObservedObject var store: BottleStore
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.dismiss) private var dismiss

    private let system = DiagnosticReport.systemInfo()

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    checks
                    actions
                }
                .padding(28)
            }

            Divider()
            HStack {
                Spacer()
                Button("Skip for now") { finish {} }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 14)
        }
        .frame(width: 520, height: 600)
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "shippingbox.fill")
                .font(.system(size: 40))
                .foregroundStyle(.tint)
            Text("Welcome to BottleLite")
                .font(.largeTitle.bold())
            Text("Run Windows apps and games on your Mac. Each app lives in its own isolated bottle.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var checks: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Your Mac")
                .font(.headline)
                .padding(.bottom, 8)

            checkRow(
                ok: true, symbol: "checkmark.circle.fill",
                title: "macOS", value: system.macOSVersion)
            Divider()
            checkRow(
                ok: system.cpuArchitecture.contains("Apple Silicon"),
                symbol: system.cpuArchitecture.contains("Apple Silicon")
                    ? "checkmark.circle.fill" : "info.circle.fill",
                title: "Chip", value: system.cpuArchitecture)
            Divider()
            checkRow(
                ok: store.runtimeStatus.state == .ready,
                symbol: store.runtimeStatus.state == .ready
                    ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
                title: "Wine",
                value: store.runtimeStatus.state == .ready
                    ? (store.runtimeStatus.version ?? "Installed") : "Not installed",
                trailing: store.runtimeStatus.state == .ready
                    ? nil
                    : AnyView(
                        Button("Install") { store.promptWineInstall() }
                            .controlSize(.small)))
            Divider()
            checkRow(
                ok: store.winetricksAvailable,
                symbol: store.winetricksAvailable ? "checkmark.circle.fill" : "minus.circle",
                title: "winetricks",
                value: store.winetricksAvailable ? "Installed" : "Optional — add later if an app needs it")
        }
        .padding(16)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("What would you like to do?")
                .font(.headline)

            actionButton(
                "gamecontroller.fill", "Install Steam",
                "Set up a Steam bottle and download the Steam installer.", tint: .blue
            ) { store.installSteam() }

            actionButton(
                "square.and.arrow.down", "Run a Windows App",
                "Pick a .exe or .msi to add to a bottle."
            ) { store.isImporterPresented = true }

            actionButton(
                "plus.square.on.square", "Create an Empty Bottle",
                "Start with a clean Windows environment to set up yourself."
            ) { store.createBottle() }
        }
    }

    // MARK: - Helpers

    private func checkRow(
        ok: Bool, symbol: String, title: String, value: String, trailing: AnyView? = nil
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(ok ? Color.green : Color.orange)
            Text(title)
                .frame(width: 84, alignment: .leading)
            Text(value)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            if let trailing { trailing }
        }
        .padding(.vertical, 8)
    }

    private func actionButton(
        _ symbol: String, _ title: String, _ detail: String, tint: Color = .secondary,
        perform: @escaping () -> Void
    ) -> some View {
        Button {
            finish(perform)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.title2)
                    .foregroundStyle(tint == .secondary ? Color.accentColor : tint)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline)
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func finish(_ action: () -> Void) {
        hasCompletedOnboarding = true
        action()
        dismiss()
    }
}
