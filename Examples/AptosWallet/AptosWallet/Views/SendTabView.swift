import SwiftUI

struct SendTabView: View {
    @Bindable var vm: WalletViewModel
    @State private var recipientAddress = ""
    @State private var amountString = ""
    @State private var showConfirmation = false

    private var octasAmount: UInt64? {
        FormatUtils.aptToOctas(amountString)
    }

    private var canSend: Bool {
        !recipientAddress.isEmpty && (octasAmount ?? 0) > 0 && !vm.isSending
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Recipient") {
                    HStack {
                        TextField("0x... address", text: $recipientAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.system(.body, design: .monospaced))
                        Button {
                            if let str = UIPasteboard.general.string {
                                recipientAddress = str.trimmingCharacters(in: .whitespacesAndNewlines)
                            }
                        } label: {
                            Image(systemName: "doc.on.clipboard")
                        }
                        .buttonStyle(.borderless)
                    }
                }

                Section {
                    TextField("0.0", text: $amountString)
                        .keyboardType(.decimalPad)
                        .font(.system(.title2, design: .rounded))

                    if let octas = octasAmount {
                        Text("\(octas) octas")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Amount (APT)")
                } footer: {
                    Text("Available: \(FormatUtils.aptDisplay(vm.balance))")
                }

                Section {
                    Button {
                        showConfirmation = true
                    } label: {
                        if vm.isSending {
                            HStack {
                                ProgressView()
                                Text("Sending...")
                            }
                            .frame(maxWidth: .infinity)
                        } else {
                            Text("Send APT")
                                .frame(maxWidth: .infinity)
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(!canSend)
                }

                if let hash = vm.lastTxHash {
                    Section("Last Transaction") {
                        AddressDisplayView(label: "Hash", value: hash)
                    }
                }
            }
            .navigationTitle("Send")
            .alert("Confirm Transfer", isPresented: $showConfirmation) {
                Button("Send", role: .destructive) {
                    guard let octas = octasAmount else { return }
                    Task {
                        await vm.sendAPT(to: recipientAddress, amount: octas)
                        recipientAddress = ""
                        amountString = ""
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                if let octas = octasAmount {
                    Text("Send \(FormatUtils.aptDisplay(octas)) to \(FormatUtils.truncateAddress(recipientAddress))?")
                }
            }
        }
    }
}
