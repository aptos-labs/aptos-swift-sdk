import Foundation
import AptosSDK

@Observable @MainActor
final class LedgerInfoViewModel {
    var ledgerInfo: LedgerInfo?
    var gasEstimate: GasEstimate?
    var isLoading = false
    var autoRefresh = false
    var errorMessage: String?

    private var refreshTask: Task<Void, Never>?

    func load(client: AptosClient) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            async let info = client.general.getLedgerInfo()
            async let gas = client.general.estimateGasPrice()
            let (infoResult, gasResult) = try await (info, gas)
            ledgerInfo = infoResult
            gasEstimate = gasResult
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func startAutoRefresh(client: AptosClient) {
        stopAutoRefresh()
        autoRefresh = true
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.load(client: client)
                try? await Task.sleep(for: .seconds(5))
            }
        }
    }

    func stopAutoRefresh() {
        autoRefresh = false
        refreshTask?.cancel()
        refreshTask = nil
    }

    func clear() {
        stopAutoRefresh()
        ledgerInfo = nil
        gasEstimate = nil
        errorMessage = nil
    }
}
