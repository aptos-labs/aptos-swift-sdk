import Foundation

/// Supported Aptos networks.
public enum Network: String, Sendable, Hashable, CaseIterable, Codable {
    case mainnet = "mainnet"
    case testnet = "testnet"
    case devnet = "devnet"
    case shelbynet = "shelbynet"
    case netna = "netna"
    case local = "local"
    case custom = "custom"
}

/// API endpoint types.
public enum AptosAPIType: String, Sendable {
    case fullnode = "Fullnode"
    case indexer = "Indexer"
    case faucet = "Faucet"
    case pepper = "Pepper"
    case prover = "Prover"
}
