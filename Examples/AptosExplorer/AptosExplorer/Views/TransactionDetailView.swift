import SwiftUI
import AptosSDK

struct TransactionDetailView: View {
    let transaction: TransactionResponse

    var body: some View {
        List {
            Section("Overview") {
                CopyableText(label: "Hash", text: transaction.hash)
                if let sender = transaction.sender {
                    CopyableText(label: "Sender", text: sender)
                }
                HStack {
                    Text("Status")
                        .foregroundStyle(.secondary)
                    Spacer()
                    StatusBadge(success: transaction.success)
                }
            }

            Section("Details") {
                if let version = transaction.version {
                    KeyValueRow(key: "Version", value: FormatUtils.formatNumber(version))
                }
                if let gas = transaction.gasUsed {
                    KeyValueRow(key: "Gas Used", value: gas)
                }
                if let maxGas = transaction.maxGasAmount {
                    KeyValueRow(key: "Max Gas", value: maxGas)
                }
                if let gasPrice = transaction.gasUnitPrice {
                    KeyValueRow(key: "Gas Price", value: gasPrice)
                }
                if let seq = transaction.sequenceNumber {
                    KeyValueRow(key: "Sequence #", value: seq)
                }
                if let ts = transaction.timestamp {
                    KeyValueRow(key: "Timestamp", value: FormatUtils.formatTimestamp(ts))
                }
                if let vm = transaction.vmStatus {
                    KeyValueRow(key: "VM Status", value: vm)
                }
            }

            if let payload = transaction.payload {
                Section("Payload") {
                    JSONTreeView(payload.value)
                }
            }

            if let events = transaction.events, !events.isEmpty {
                Section("Events (\(events.count))") {
                    ForEach(Array(events.enumerated()), id: \.offset) { _, event in
                        DisclosureGroup {
                            JSONTreeView(event.data.value)
                        } label: {
                            Text(event.type)
                                .font(.system(.caption, design: .monospaced))
                                .lineLimit(2)
                        }
                    }
                }
            }
        }
        .navigationTitle("Transaction")
    }
}
