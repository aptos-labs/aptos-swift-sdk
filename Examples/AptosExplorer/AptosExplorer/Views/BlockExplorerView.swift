import SwiftUI
import AptosSDK

struct BlockExplorerView: View {
    let client: AptosClient
    @State private var vm = BlockExplorerViewModel()

    var body: some View {
        List {
            Section {
                HStack {
                    TextField("Block height", text: $vm.heightInput)
                    #if os(iOS)
                        .keyboardType(.numberPad)
                    #endif
                        .onSubmit {
                            Task { await vm.loadBlock(client: client) }
                        }
                    Button("Lookup") {
                        Task { await vm.loadBlock(client: client) }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(vm.heightInput.isEmpty || vm.isLoading)
                }
                Button("Load Latest Block") {
                    Task { await vm.loadLatest(client: client) }
                }
                .disabled(vm.isLoading)
            }

            if let error = vm.errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                }
            }

            if let block = vm.block {
                Section("Block Details") {
                    KeyValueRow(key: "Height", value: FormatUtils.formatNumber(block.blockHeight))
                    CopyableText(label: "Hash", text: block.blockHash)
                    KeyValueRow(key: "Timestamp", value: FormatUtils.formatTimestamp(block.blockTimestamp))
                    KeyValueRow(key: "First Version", value: FormatUtils.formatNumber(block.firstVersion))
                    KeyValueRow(key: "Last Version", value: FormatUtils.formatNumber(block.lastVersion))
                }

                Section {
                    HStack {
                        Button {
                            Task { await vm.goToPrevious(client: client) }
                        } label: {
                            Label("Previous", systemImage: "chevron.left")
                        }
                        .disabled(vm.isLoading || (UInt64(block.blockHeight) ?? 0) == 0)

                        Spacer()

                        Button {
                            Task { await vm.goToNext(client: client) }
                        } label: {
                            Label("Next", systemImage: "chevron.right")
                        }
                        .disabled(vm.isLoading)
                    }
                }

                if let transactions = block.transactions, !transactions.isEmpty {
                    Section("Transactions (\(transactions.count))") {
                        ForEach(transactions, id: \.hash) { tx in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(FormatUtils.truncateAddress(tx.hash))
                                        .font(.system(.subheadline, design: .monospaced))
                                    Spacer()
                                    StatusBadge(success: tx.success)
                                }
                                if let sender = tx.sender {
                                    Text("From: \(FormatUtils.truncateAddress(sender))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
        .overlay {
            if vm.isLoading && vm.block == nil {
                ProgressView("Loading...")
            }
        }
        .navigationTitle("Block Explorer")
    }
}
