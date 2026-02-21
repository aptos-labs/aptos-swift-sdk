import SwiftUI
import AptosSDK

struct WalletTabView: View {
    @Bindable var vm: WalletViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    BalanceCardView(balance: vm.balance, isLoading: vm.isLoading)

                    Button {
                        Task { await vm.fundFromFaucet() }
                    } label: {
                        Label("Fund from Faucet", systemImage: "drop.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(vm.isLoading)

                    if !vm.recentTransactions.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Recent Transactions")
                                .font(.headline)
                                .padding(.horizontal)

                            ForEach(vm.recentTransactions, id: \.hash) { tx in
                                TransactionRowView(
                                    transaction: tx,
                                    currentAddress: vm.account?.accountAddress.toHex() ?? ""
                                )
                                .padding(.horizontal)
                                if tx.hash != vm.recentTransactions.last?.hash {
                                    Divider().padding(.horizontal)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding()
            }
            .navigationTitle("Wallet")
            .refreshable {
                await vm.refreshAll()
            }
            .task {
                await vm.refreshAll()
            }
        }
    }
}
