import SwiftUI
import AptosSDK

struct TransactionLookupView: View {
    let client: AptosClient
    @State private var vm = TransactionLookupViewModel()

    var body: some View {
        List {
            Section {
                HStack {
                    TextField("Transaction hash (0x...)", text: $vm.hashInput)
                    #if os(iOS)
                        .textInputAutocapitalization(.never)
                    #endif
                        .autocorrectionDisabled()
                        .font(.system(.body, design: .monospaced))
                        .onSubmit {
                            Task { await vm.lookupByHash(client: client) }
                        }
                    Button("Lookup") {
                        Task { await vm.lookupByHash(client: client) }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(vm.hashInput.isEmpty || vm.isLoading)
                }
                Button("Load Recent Transactions") {
                    Task { await vm.loadRecent(client: client) }
                }
                .disabled(vm.isLoading)
            }

            if let error = vm.errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                }
            }

            if let tx = vm.transaction {
                TransactionDetailSection(transaction: tx)
            }

            if !vm.recentTransactions.isEmpty {
                Section("Recent Transactions") {
                    ForEach(vm.recentTransactions, id: \.hash) { tx in
                        Button {
                            vm.selectTransaction(tx)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(FormatUtils.truncateAddress(tx.hash))
                                        .font(.system(.subheadline, design: .monospaced))
                                    if let sender = tx.sender {
                                        Text("From: \(FormatUtils.truncateAddress(sender))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                StatusBadge(success: tx.success)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .overlay {
            if vm.isLoading && vm.transaction == nil && vm.recentTransactions.isEmpty {
                ProgressView("Loading...")
            }
        }
        .navigationTitle("Transaction Lookup")
    }
}

private struct TransactionDetailSection: View {
    let transaction: TransactionResponse

    var body: some View {
        Section("Transaction Detail") {
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
                KeyValueRow(key: "Gas Unit Price", value: gasPrice)
            }
            if let seq = transaction.sequenceNumber {
                KeyValueRow(key: "Sequence Number", value: seq)
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
}
