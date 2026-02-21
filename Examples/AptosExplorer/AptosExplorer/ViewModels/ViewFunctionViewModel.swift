import Foundation
import AptosSDK

@Observable @MainActor
final class ViewFunctionViewModel {
    var functionName = ""
    var typeArguments: [String] = [""]
    var arguments: [String] = [""]
    var result: String?
    var isLoading = false
    var errorMessage: String?
    var selectedPreset: ViewFunctionPreset?

    func execute(client: AptosClient) async {
        let trimmed = functionName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Please enter a function name."
            return
        }

        isLoading = true
        errorMessage = nil
        result = nil
        defer { isLoading = false }

        let typeArgs = typeArguments
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let args: [Any] = arguments
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        do {
            let response = try await client.view.view(
                function: trimmed,
                typeArguments: typeArgs,
                arguments: args
            )
            let values = response.map { "\($0.value)" }
            result = values.joined(separator: "\n")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func applyPreset(_ preset: ViewFunctionPreset) {
        selectedPreset = preset
        functionName = preset.function
        typeArguments = preset.typeArguments.isEmpty ? [""] : preset.typeArguments
        arguments = preset.argumentPlaceholders.isEmpty ? [""] : preset.argumentPlaceholders.map { _ in "" }
        result = nil
        errorMessage = nil
    }

    func addTypeArgument() {
        typeArguments.append("")
    }

    func removeTypeArgument(at index: Int) {
        guard typeArguments.count > 1 else { return }
        typeArguments.remove(at: index)
    }

    func addArgument() {
        arguments.append("")
    }

    func removeArgument(at index: Int) {
        guard arguments.count > 1 else { return }
        arguments.remove(at: index)
    }

    func clear() {
        result = nil
        errorMessage = nil
    }
}
