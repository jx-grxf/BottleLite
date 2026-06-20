import SwiftUI
import UniformTypeIdentifiers

struct DropZoneView: View {
    @ObservedObject var store: BottleStore
    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "app.badge")
                .font(.system(size: 44, weight: .regular))
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: 3) {
                Text("Drop a Windows app or installer")
                    .font(.title3.weight(.semibold))
                Text("BottleLite imports .exe files and runs .msi installers in the selected bottle.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Button {
                store.isImporterPresented = true
            } label: {
                Label("Choose File", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isTargeted ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.08))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(
                    isTargeted ? Color.accentColor : Color.secondary.opacity(0.25),
                    style: StrokeStyle(lineWidth: 1, dash: [7, 5])
                )
        }
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            guard let provider = providers.first else { return false }

            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                guard
                    let data = item as? Data,
                    let url = URL(dataRepresentation: data, relativeTo: nil)
                else {
                    return
                }

                Task { @MainActor in
                    store.openWindowsFile(at: url)
                }
            }

            return true
        }
    }
}
