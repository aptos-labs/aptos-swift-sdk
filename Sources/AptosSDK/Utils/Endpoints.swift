import Foundation

/// Network endpoint URL configuration.
public enum Endpoints {
    // MARK: - Full Node REST API

    /// Returns the full node API URL for the given network.
    public static func fullnodeURL(for network: Network) -> String? {
        switch network {
        case .mainnet: return "https://api.mainnet.aptoslabs.com/v1"
        case .testnet: return "https://api.testnet.aptoslabs.com/v1"
        case .devnet: return "https://api.devnet.aptoslabs.com/v1"
        case .local: return "http://127.0.0.1:8080/v1"
        case .custom: return nil
        }
    }

    // MARK: - Indexer GraphQL API

    /// Returns the indexer GraphQL URL for the given network.
    public static func indexerURL(for network: Network) -> String? {
        switch network {
        case .mainnet: return "https://api.mainnet.aptoslabs.com/v1/graphql"
        case .testnet: return "https://api.testnet.aptoslabs.com/v1/graphql"
        case .devnet: return "https://api.devnet.aptoslabs.com/v1/graphql"
        case .local: return "http://127.0.0.1:8090/v1/graphql"
        case .custom: return nil
        }
    }

    // MARK: - Faucet API

    /// Returns the faucet URL for the given network.
    public static func faucetURL(for network: Network) -> String? {
        switch network {
        case .devnet: return "https://faucet.devnet.aptoslabs.com"
        case .local: return "http://127.0.0.1:8081"
        case .mainnet, .testnet, .custom: return nil
        }
    }

    // MARK: - Keyless Services

    /// Returns the pepper service URL for the given network.
    public static func pepperServiceURL(for network: Network) -> String? {
        guard let base = fullnodeURL(for: network) else { return nil }
        let apiBase = base.replacingOccurrences(of: "/v1", with: "")
        return "\(apiBase)/keyless/pepper/v0"
    }

    /// Returns the prover service URL for the given network.
    public static func proverServiceURL(for network: Network) -> String? {
        guard let base = fullnodeURL(for: network) else { return nil }
        let apiBase = base.replacingOccurrences(of: "/v1", with: "")
        return "\(apiBase)/keyless/prover/v0"
    }
}
