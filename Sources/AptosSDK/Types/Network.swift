import Foundation

/// Network presets for the Aptos blockchain.
public enum Network: String, Sendable, CaseIterable {
    case mainnet
    case testnet
    case devnet
    case local
    case custom

    /// Chain ID for predefined networks.
    public var chainId: ChainId? {
        switch self {
        case .mainnet: return .mainnet
        case .testnet: return .testnet
        case .local: return .local
        case .devnet, .custom: return nil
        }
    }
}
