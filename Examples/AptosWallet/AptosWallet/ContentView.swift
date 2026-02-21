import SwiftUI

struct ContentView: View {
    @State private var vm = WalletViewModel()
    @State private var showImportSheet = false
    @State private var importPhrase = ""

    var body: some View {
        TabView {
            WalletTabView(vm: vm)
                .tabItem { Label("Wallet", systemImage: "creditcard.fill") }
            SendTabView(vm: vm)
                .tabItem { Label("Send", systemImage: "paperplane.fill") }
            SettingsTabView(vm: vm)
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .sheet(isPresented: $vm.showOnboarding) {
            onboardingSheet
        }
        .alert(item: $vm.error) { error in
            Alert(
                title: Text(error.title),
                message: Text(error.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private var onboardingSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: "wallet.bifold.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.tint)
                Text("Aptos Wallet")
                    .font(.largeTitle.bold())
                Text("A sample wallet for the Aptos devnet")
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    vm.createAccount()
                    Task { await vm.refreshAll() }
                } label: {
                    Text("Create New Wallet")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button {
                    showImportSheet = true
                } label: {
                    Text("Import from Recovery Phrase")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding()
            .navigationTitle("Welcome")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showImportSheet) {
                importSheet
            }
        }
        .interactiveDismissDisabled()
    }

    private var importSheet: some View {
        NavigationStack {
            Form {
                Section("Enter Recovery Phrase") {
                    TextEditor(text: $importPhrase)
                        .frame(minHeight: 100)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                Section {
                    Button("Import Wallet") {
                        vm.importAccount(importPhrase.trimmingCharacters(in: .whitespacesAndNewlines))
                    }
                    .disabled(importPhrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle("Import")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }
}
