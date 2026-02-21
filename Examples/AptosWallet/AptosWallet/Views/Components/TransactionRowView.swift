import SwiftUI
import AptosSDK

struct TransactionRowView: View {
    let transaction: TransactionResponse
    let currentAddress: String

    var body: some View {
        HStack {
            Image(systemName: iconName)
                .foregroundStyle(iconColor)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                if let ts = transaction.timestamp {
                    Text(FormatUtils.formatTimestamp(ts))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                if let gas = transaction.gasUsed {
                    Text("-\(gas) gas")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                statusBadge
            }
        }
        .padding(.vertical, 4)
    }

    private var isSentByMe: Bool {
        transaction.sender?.lowercased() == currentAddress.lowercased()
    }

    private var iconName: String {
        if transaction.isPending { return "clock" }
        if transaction.success == true {
            return isSentByMe ? "arrow.up.circle.fill" : "arrow.down.circle.fill"
        }
        return "xmark.circle.fill"
    }

    private var iconColor: Color {
        if transaction.isPending { return .orange }
        if transaction.success == true { return isSentByMe ? .blue : .green }
        return .red
    }

    private var title: String {
        let hash = transaction.hash
        return FormatUtils.truncateAddress(hash)
    }

    @ViewBuilder
    private var statusBadge: some View {
        if transaction.isPending {
            Text("Pending")
                .font(.caption2)
                .foregroundStyle(.orange)
        } else if transaction.success == true {
            Text("Success")
                .font(.caption2)
                .foregroundStyle(.green)
        } else {
            Text("Failed")
                .font(.caption2)
                .foregroundStyle(.red)
        }
    }
}
