import SwiftUI
import AptosSDK

struct ViewFunctionView: View {
    let client: AptosClient
    @State private var vm = ViewFunctionViewModel()

    var body: some View {
        List {
            Section("Presets") {
                Picker("Preset", selection: Binding(
                    get: { vm.selectedPreset },
                    set: { if let p = $0 { vm.applyPreset(p) } }
                )) {
                    Text("Custom").tag(nil as ViewFunctionPreset?)
                    ForEach(ViewFunctionPreset.presets) { preset in
                        Text(preset.name).tag(preset as ViewFunctionPreset?)
                    }
                }
            }

            Section("Function") {
                TextField("e.g. 0x1::coin::balance", text: $vm.functionName)
                #if os(iOS)
                    .textInputAutocapitalization(.never)
                #endif
                    .autocorrectionDisabled()
                    .font(.system(.body, design: .monospaced))
            }

            Section {
                ForEach(Array(vm.typeArguments.enumerated()), id: \.offset) { index, _ in
                    HStack {
                        TextField("Type argument \(index)", text: $vm.typeArguments[index])
                        #if os(iOS)
                            .textInputAutocapitalization(.never)
                        #endif
                            .autocorrectionDisabled()
                            .font(.system(.body, design: .monospaced))
                        if vm.typeArguments.count > 1 {
                            Button(role: .destructive) {
                                vm.removeTypeArgument(at: index)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
                Button("Add Type Argument") {
                    vm.addTypeArgument()
                }
            } header: {
                Text("Type Arguments")
            }

            Section {
                ForEach(Array(vm.arguments.enumerated()), id: \.offset) { index, _ in
                    HStack {
                        TextField("Argument \(index)", text: $vm.arguments[index])
                        #if os(iOS)
                            .textInputAutocapitalization(.never)
                        #endif
                            .autocorrectionDisabled()
                            .font(.system(.body, design: .monospaced))
                        if vm.arguments.count > 1 {
                            Button(role: .destructive) {
                                vm.removeArgument(at: index)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
                Button("Add Argument") {
                    vm.addArgument()
                }
            } header: {
                Text("Arguments")
            }

            Section {
                Button {
                    Task { await vm.execute(client: client) }
                } label: {
                    if vm.isLoading {
                        HStack {
                            ProgressView()
                            Text("Executing...")
                        }
                    } else {
                        Label("Execute", systemImage: "play.fill")
                    }
                }
                .disabled(vm.functionName.isEmpty || vm.isLoading)
            }

            if let error = vm.errorMessage {
                Section("Error") {
                    Text(error)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }
            }

            if let result = vm.result {
                Section("Result") {
                    Text(result)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                }
            }
        }
        .navigationTitle("View Function")
    }
}
