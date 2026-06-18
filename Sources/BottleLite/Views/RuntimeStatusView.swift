import SwiftUI

struct RuntimeStatusView: View {
    let status: RuntimeStatus

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: iconName)
                .foregroundStyle(iconColor)

            VStack(alignment: .leading, spacing: 1) {
                Text(status.message)
                    .font(.callout.weight(.medium))
                if let winePath = status.winePath {
                    Text(winePath)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var iconName: String {
        switch status.state {
        case .ready: "checkmark.circle.fill"
        case .missing: "xmark.circle.fill"
        case .unknown: "questionmark.circle"
        }
    }

    private var iconColor: Color {
        switch status.state {
        case .ready: .green
        case .missing: .orange
        case .unknown: .secondary
        }
    }
}
