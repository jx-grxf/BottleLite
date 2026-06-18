import SwiftUI

struct SidebarView: View {
    @ObservedObject var store: BottleStore

    var body: some View {
        List(selection: $store.selection) {
            Section("Bottles") {
                ForEach(store.bottles) { bottle in
                    BottleRowView(bottle: bottle)
                        .tag(bottle.id)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("BottleLite")
    }
}

private struct BottleRowView: View {
    let bottle: Bottle

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(bottle.name)
                    .font(.body)
                Text("\(bottle.programs.count) programs")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: "shippingbox")
                .symbolRenderingMode(.hierarchical)
        }
        .padding(.vertical, 3)
    }
}
