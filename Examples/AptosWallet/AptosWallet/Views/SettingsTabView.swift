import SwiftUI

struct SettingsTabView: View {
    @Bindable var vm: WalletViewModel
    @State private var showPrivateKey = false
    @State private var showMnemonic = false
    @State private var showImportSheet = false
    @State private var showResetAlert = false
    @State private var importPhrase = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    if let account = vm.account {
                        AddressDisplayView(
                            label: "Address",
                            value: account.accountAddress.toHex()
                        )
                        AddressDisplayView(
                            label: "Public Key",
                            value: account.publicKey.toHex()
                        )
                    }
                }

                Section("Security") {
                    Button("Reveal Private Key") {
                        showPrivateKey = true
                    }
                    Button("Reveal Recovery Phrase") {
                        showMnemonic = true
                    }
                }

                Section("Network") {
                    HStack {
                        Text("Network")
                        Spacer()
                        Text("Devnet")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Manage") {
                    Button("Import Wallet") {
                        importPhrase = ""
                        showImportSheet = true
                    }
                    Button("Create New Wallet", role: .destructive) {
                        showResetAlert = true
                    }
                }
            }
            .navigationTitle("Settings")
            .alert("Private Key", isPresented: $showPrivateKey) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(vm.account?.privateKey.toAIP80() ?? "No account")
            }
            .alert("Recovery Phrase", isPresented: $showMnemonic) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(vm.mnemonic ?? "No mnemonic")
            }
            .alert("Create New Wallet?", isPresented: $showResetAlert) {
                Button("Create New", role: .destructive) {
                    vm.resetAccount()
                    vm.createAccount()
                    Task { await vm.refreshAll() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will replace your current wallet. Make sure you have saved your recovery phrase.")
            }
            .sheet(isPresented: $showImportSheet) {
                NavigationStack {
                    Form {
                        Section("Recovery Phrase") {
                            TextEditor(text: $importPhrase)
                                .frame(minHeight: 100)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        }
                        Section {
                            Button("Import") {
                                vm.importAccount(importPhrase.trimmingCharacters(in: .whitespacesAndNewlines))
                                showImportSheet = false
                            }
                            .disabled(importPhrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                    .navigationTitle("Import Wallet")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showImportSheet = false }
                        }
                    }
                }
                .presentationDetents([.medium])
            }
        }
    }
}
