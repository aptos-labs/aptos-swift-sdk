import Foundation
import AptosSDK

@Observable @MainActor
final class AppState {
    var selectedNetwork: Network = .testnet {
        didSet {
            if oldValue != selectedNetwork {
                aptosClient = AptosClient(selectedNetwork)
            }
        }
    }
    var aptosClient: AptosClient

    init() {
        aptosClient = AptosClient(.testnet)
    }
}
