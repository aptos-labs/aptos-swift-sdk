import SwiftUI
import AptosSDK

struct LedgerInfoView: View {
    let client: AptosClient
    @State private var vm = LedgerInfoViewModel()

    var body: some View {
        List {
            if let info = vm.ledgerInfo {
                Section("Chain") {
                    KeyValueRow(key: "Chain ID", value: "\(info.chainId)")
                    KeyValueRow(key: "Epoch", value: FormatUtils.formatNumber(info.epoch))
                    KeyValueRow(key: "Ledger Version", value: FormatUtils.formatNumber(info.ledgerVersion))
                    if let height = info.blockHeight {
                        KeyValueRow(key: "Block Height", value: FormatUtils.formatNumber(height))
                    }
                    KeyValueRow(key: "Timestamp", value: FormatUtils.formatTimestamp(info.ledgerTimestamp))
                    KeyValueRow(key: "Oldest Version", value: FormatUtils.formatNumber(info.oldestLedgerVersion))
                    if let role = info.nodeRole {
                        KeyValueRow(key: "Node Role", value: role)
                    }
                    if let gitHash = info.gitHash {
                        KeyValueRow(key: "Git Hash", value: FormatUtils.truncateAddress(gitHash))
                    }
                }

                if let gas = vm.gasEstimate {
                    Section("Gas Estimate") {
                        KeyValueRow(key: "Gas Estimate", value: "\(gas.gasEstimate)")
                        if let depri = gas.deprioritizedGasEstimate {
                            KeyValueRow(key: "Deprioritized", value: "\(depri)")
                        }
                        if let pri = gas.prioritizedGasEstimate {
                            KeyValueRow(key: "Prioritized", value: "\(pri)")
                        }
                    }
                }
            }

            if vm.ledgerInfo == nil && !vm.isLoading {
                LoadingStateView(
                    isLoading: vm.isLoading,
                    errorMessage: vm.errorMessage,
                    isEmpty: true,
                    emptyText: "Tap refresh to load ledger info"
                )
            }
        }
        .overlay {
            if vm.isLoading && vm.ledgerInfo == nil {
                ProgressView("Loading...")
            }
        }
        .navigationTitle("Ledger Info")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Toggle(isOn: Binding(
                    get: { vm.autoRefresh },
                    set: { newValue in
                        if newValue {
                            vm.startAutoRefresh(client: client)
                        } else {
                            vm.stopAutoRefresh()
                        }
                    }
                )) {
                    Label("Auto-refresh", systemImage: "arrow.clockwise")
                }
            }
            ToolbarItem(placement: .automatic) {
                Button {
                    Task { await vm.load(client: client) }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(vm.isLoading)
            }
        }
        .task {
            await vm.load(client: client)
        }
    }
}
