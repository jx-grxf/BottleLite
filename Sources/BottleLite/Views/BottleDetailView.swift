import SwiftUI

struct BottleDetailView: View {
    @ObservedObject var store: BottleStore

    var body: some View {
        VStack(spacing: 0) {
            HeaderView(store: store)

            Divider()

            if let bottle = store.selectedBottle {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        DropZoneView(store: store)
                        ProgramListView(bottle: bottle, store: store)
                    }
                    .padding(24)
                }
            } else {
                ContentUnavailableView(
                    "No Bottle Selected",
                    systemImage: "shippingbox",
                    description: Text("Create a bottle or select one from the sidebar.")
                )
            }
        }
        .navigationTitle(store.selectedBottle?.name ?? "BottleLite")
        .alert("Install Wine?", isPresented: $store.isWineInstallPromptPresented) {
            Button("Cancel", role: .cancel) {}
            Button("Install Wine") {
                Task {
                    await store.installWine()
                }
            }
        } message: {
            Text("BottleLite can install Wine using Homebrew so Windows executables can be launched.")
        }
    }
}

private struct HeaderView: View {
    @ObservedObject var store: BottleStore

    var body: some View {
        HStack(spacing: 14) {
            RuntimeStatusView(status: store.runtimeStatus)

            if store.runtimeStatus.state == .missing {
                Button {
                    store.promptWineInstall()
                } label: {
                    Label("Install Wine", systemImage: "arrow.down.circle")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(store.wineInstallState == .installing)
            }

            Spacer()

            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(.regularMaterial)
    }

    private var message: String {
        switch store.wineInstallState {
        case .idle:
            store.lastMessage
        case .installing:
            "Installing Wine..."
        case let .failed(error):
            error
        }
    }
}
