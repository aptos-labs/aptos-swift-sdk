import Foundation
import AptosSDK

@Observable @MainActor
final class TransactionLookupViewModel {
    var hashInput = ""
    var transaction: TransactionResponse?
    var recentTransactions: [TransactionResponse] = []
    var isLoading = false
    var errorMessage: String?

    func lookupByHash(client: AptosClient) async {
        let trimmed = hashInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            transaction = try await client.transaction.getTransactionByHash(trimmed)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadRecent(client: AptosClient) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            recentTransactions = try await client.transaction.getTransactions(limit: 20)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func selectTransaction(_ tx: TransactionResponse) {
        transaction = tx
        hashInput = tx.hash
    }

    func clear() {
        transaction = nil
        recentTransactions = []
        errorMessage = nil
    }
}
