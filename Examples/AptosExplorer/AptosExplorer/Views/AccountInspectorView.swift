import SwiftUI
import AptosSDK

struct AccountInspectorView: View {
    let client: AptosClient
    @State private var vm = AccountInspectorViewModel()

    var body: some View {
        List {
            Section {
                HStack {
                    TextField("Account address (0x...)", text: $vm.addressInput)
                    #if os(iOS)
                        .textInputAutocapitalization(.never)
                    #endif
                        .autocorrectionDisabled()
                        .font(.system(.body, design: .monospaced))
                        .onSubmit {
                            Task { await vm.lookup(client: client) }
                        }
                    Button("Lookup") {
                        Task { await vm.lookup(client: client) }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(vm.addressInput.isEmpty || vm.isLoading)
                }
            }

            if let error = vm.errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                }
            }

            if let account = vm.accountData {
                Section("Account Data") {
                    KeyValueRow(key: "Sequence Number", value: account.sequenceNumber)
                    CopyableText(label: "Auth Key", text: account.authenticationKey)
                }
            }

            if let balance = vm.balance {
                Section("Balance") {
                    KeyValueRow(key: "APT Balance", value: FormatUtils.aptDisplay(balance))
                    KeyValueRow(key: "Octas", value: FormatUtils.formatNumber(String(balance)))
                }
            }

            if !vm.resources.isEmpty {
                Section("Resources (\(vm.resources.count))") {
                    ForEach(Array(vm.resources.enumerated()), id: \.offset) { _, resource in
                        DisclosureGroup {
                            JSONTreeView(resource.data.value)
                        } label: {
                            Text(resource.type)
                                .font(.system(.caption, design: .monospaced))
                                .lineLimit(2)
                        }
                    }
                }
            }

            if !vm.modules.isEmpty {
                Section("Modules (\(vm.modules.count))") {
                    ForEach(Array(vm.modules.enumerated()), id: \.offset) { _, module in
                        if let abi = module.abi {
                            DisclosureGroup {
                                JSONTreeView(abi)
                            } label: {
                                Text(abi.name)
                                    .font(.system(.body, design: .monospaced))
                            }
                        } else {
                            Text("Module (no ABI)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .overlay {
            if vm.isLoading {
                ProgressView("Loading...")
            }
        }
        .navigationTitle("Account Inspector")
    }
}
