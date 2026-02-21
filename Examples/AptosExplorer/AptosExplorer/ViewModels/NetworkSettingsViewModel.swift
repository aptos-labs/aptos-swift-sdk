import Foundation
import AptosSDK

@Observable @MainActor
final class NetworkSettingsViewModel {
    var isTesting = false
    var connectionResult: String?
    var errorMessage: String?

    func testConnection(client: AptosClient) async {
        isTesting = true
        connectionResult = nil
        errorMessage = nil
        defer { isTesting = false }

        do {
            let info = try await client.general.getLedgerInfo()
            connectionResult = "Connected! Chain ID: \(info.chainId), Epoch: \(info.epoch), Version: \(info.ledgerVersion)"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    var fullnodeURL: String {
        "https://fullnode.[network].aptoslabs.com/v1"
    }

    func clear() {
        connectionResult = nil
        errorMessage = nil
    }
}
