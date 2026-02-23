import Foundation

/// Network presets for the Aptos blockchain.
///
/// Each preset resolves to default API endpoint URLs via ``Endpoints``.
/// Use `.custom` with explicit URLs in ``AptosConfig`` for non-standard deployments.
public enum Network: String, Sendable, CaseIterable {
    /// Aptos mainnet (production). Chain ID 1.
    case mainnet
    /// Aptos testnet (persistent test network with faucet). Chain ID 2.
    case testnet
    /// Aptos devnet (frequently reset development network). Chain ID 3.
    case devnet
    /// Local development network (e.g., running via `aptos node run-local-testnet`). Chain ID 4.
    case local
    /// Custom network. Requires explicit URLs in ``AptosConfig``.
    case custom

    /// Chain ID for predefined networks.
    public var chainId: ChainId? {
        switch self {
        case .mainnet: .mainnet
        case .testnet: .testnet
        case .devnet: .devnet
        case .local: .local
        case .custom: nil
        }
    }
}
