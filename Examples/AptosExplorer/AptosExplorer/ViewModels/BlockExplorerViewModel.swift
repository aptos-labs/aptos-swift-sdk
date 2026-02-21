import Foundation
import AptosSDK

@Observable @MainActor
final class BlockExplorerViewModel {
    var heightInput = ""
    var block: Block?
    var isLoading = false
    var errorMessage: String?

    func loadBlock(client: AptosClient) async {
        let trimmed = heightInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let height = UInt64(trimmed) else {
            errorMessage = "Please enter a valid block height number."
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            block = try await client.general.getBlockByHeight(height, withTransactions: true)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadLatest(client: AptosClient) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let info = try await client.general.getLedgerInfo()
            if let heightStr = info.blockHeight, let height = UInt64(heightStr) {
                heightInput = String(height)
                block = try await client.general.getBlockByHeight(height, withTransactions: true)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func goToPrevious(client: AptosClient) async {
        guard let current = block, let height = UInt64(current.blockHeight), height > 0 else { return }
        heightInput = String(height - 1)
        await loadBlock(client: client)
    }

    func goToNext(client: AptosClient) async {
        guard let current = block, let height = UInt64(current.blockHeight) else { return }
        heightInput = String(height + 1)
        await loadBlock(client: client)
    }

    func clear() {
        block = nil
        errorMessage = nil
    }
}
