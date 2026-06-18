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
                        ProgramListView(bottle: bottle)
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
    }
}

private struct HeaderView: View {
    @ObservedObject var store: BottleStore

    var body: some View {
        HStack(spacing: 14) {
            RuntimeStatusView(status: store.runtimeStatus)

            Spacer()

            Text(store.lastMessage)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(.regularMaterial)
    }
}
