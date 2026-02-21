import SwiftUI
import AptosSDK

struct NetworkSettingsView: View {
    @Bindable var appState: AppState
    @State private var vm = NetworkSettingsViewModel()

    private var networkOptions: [Network] {
        [.testnet, .mainnet, .devnet]
    }

    var body: some View {
        List {
            Section("Network") {
                Picker("Network", selection: $appState.selectedNetwork) {
                    Text("Testnet").tag(Network.testnet)
                    Text("Mainnet").tag(Network.mainnet)
                    Text("Devnet").tag(Network.devnet)
                }
                .pickerStyle(.segmented)
                .onChange(of: appState.selectedNetwork) {
                    vm.clear()
                }
            }

            Section("Details") {
                KeyValueRow(key: "Network", value: appState.selectedNetwork.rawValue.capitalized)
                KeyValueRow(key: "Fullnode URL", value: fullnodeURL)
            }

            Section {
                Button {
                    Task { await vm.testConnection(client: appState.aptosClient) }
                } label: {
                    if vm.isTesting {
                        HStack {
                            ProgressView()
                            Text("Testing...")
                        }
                    } else {
                        Label("Test Connection", systemImage: "network")
                    }
                }
                .disabled(vm.isTesting)
            }

            if let result = vm.connectionResult {
                Section("Connection Result") {
                    Text(result)
                        .foregroundStyle(.green)
                }
            }

            if let error = vm.errorMessage {
                Section("Error") {
                    Text(error)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Network Settings")
    }

    private var fullnodeURL: String {
        switch appState.selectedNetwork {
        case .mainnet: return "https://fullnode.mainnet.aptoslabs.com/v1"
        case .testnet: return "https://fullnode.testnet.aptoslabs.com/v1"
        case .devnet: return "https://fullnode.devnet.aptoslabs.com/v1"
        default: return "Unknown"
        }
    }
}
