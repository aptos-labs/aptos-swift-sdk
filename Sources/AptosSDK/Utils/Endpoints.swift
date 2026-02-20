import Foundation

/// Network endpoint URLs.
public enum NetworkEndpoints {
    // MARK: - Full Node REST API

    public static func fullnodeURL(for network: Network) -> String? {
        switch network {
        case .mainnet: return "https://api.mainnet.aptoslabs.com/v1"
        case .testnet: return "https://api.testnet.aptoslabs.com/v1"
        case .devnet: return "https://api.devnet.aptoslabs.com/v1"
        case .shelbynet: return "https://api.shelbynet.shelby.xyz/v1"
        case .netna: return "https://api.netna.staging.aptoslabs.com/v1"
        case .local: return "http://127.0.0.1:8080/v1"
        case .custom: return nil
        }
    }

    // MARK: - Indexer GraphQL API

    public static func indexerURL(for network: Network) -> String? {
        switch network {
        case .mainnet: return "https://api.mainnet.aptoslabs.com/v1/graphql"
        case .testnet: return "https://api.testnet.aptoslabs.com/v1/graphql"
        case .devnet: return "https://api.devnet.aptoslabs.com/v1/graphql"
        case .local: return "http://127.0.0.1:8090/v1/graphql"
        case .shelbynet, .netna, .custom: return nil
        }
    }

    // MARK: - Faucet API

    public static func faucetURL(for network: Network) -> String? {
        switch network {
        case .devnet: return "https://faucet.devnet.aptoslabs.com"
        case .shelbynet: return "https://faucet.shelbynet.shelby.xyz"
        case .local: return "http://127.0.0.1:8081"
        case .mainnet, .testnet, .netna, .custom: return nil
        }
    }

    // MARK: - Pepper Service API

    public static func pepperURL(for network: Network) -> String? {
        switch network {
        case .mainnet: return "https://api.mainnet.aptoslabs.com/keyless/pepper/v0"
        case .testnet: return "https://api.testnet.aptoslabs.com/keyless/pepper/v0"
        case .devnet, .local: return "https://api.devnet.aptoslabs.com/keyless/pepper/v0"
        case .shelbynet, .netna, .custom: return nil
        }
    }

    // MARK: - Prover Service API

    public static func proverURL(for network: Network) -> String? {
        switch network {
        case .mainnet: return "https://api.mainnet.aptoslabs.com/keyless/prover/v0"
        case .testnet: return "https://api.testnet.aptoslabs.com/keyless/prover/v0"
        case .devnet, .local: return "https://api.devnet.aptoslabs.com/keyless/prover/v0"
        case .shelbynet, .netna, .custom: return nil
        }
    }

    // MARK: - Chain IDs

    public static func chainId(for network: Network) -> UInt8? {
        switch network {
        case .mainnet: return 1
        case .testnet: return 2
        case .local: return 4
        default: return nil
        }
    }
}
