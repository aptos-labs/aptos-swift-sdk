import Foundation

/// Per-endpoint configuration.
public struct EndpointConfig: Sendable {
    public let url: String?
    public let headers: [String: String]?

    public init(url: String? = nil, headers: [String: String]? = nil) {
        self.url = url
        self.headers = headers
    }
}

/// Client-wide configuration shared across all endpoints.
public struct ClientConfig: Sendable {
    public let apiKey: String?
    public let headers: [String: String]?

    public init(apiKey: String? = nil, headers: [String: String]? = nil) {
        self.apiKey = apiKey
        self.headers = headers
    }
}

/// Faucet-specific configuration.
public struct FaucetConfig: Sendable {
    public let url: String?
    public let headers: [String: String]?
    public let authToken: String?

    public init(url: String? = nil, headers: [String: String]? = nil, authToken: String? = nil) {
        self.url = url
        self.headers = headers
        self.authToken = authToken
    }
}

/// SDK configuration for connecting to the Aptos network.
public struct AptosConfig: Sendable {
    public let network: Network
    public let clientConfig: ClientConfig?
    public let fullnodeConfig: EndpointConfig?
    public let indexerConfig: EndpointConfig?
    public let faucetConfig: FaucetConfig?
    public let pepperConfig: EndpointConfig?
    public let proverConfig: EndpointConfig?

    public init(
        network: Network = .devnet,
        clientConfig: ClientConfig? = nil,
        fullnodeConfig: EndpointConfig? = nil,
        indexerConfig: EndpointConfig? = nil,
        faucetConfig: FaucetConfig? = nil,
        pepperConfig: EndpointConfig? = nil,
        proverConfig: EndpointConfig? = nil
    ) {
        self.network = network
        self.clientConfig = clientConfig
        self.fullnodeConfig = fullnodeConfig
        self.indexerConfig = indexerConfig
        self.faucetConfig = faucetConfig
        self.pepperConfig = pepperConfig
        self.proverConfig = proverConfig
    }

    /// Resolve the request URL for a given API type.
    public func getRequestURL(for apiType: AptosAPIType) throws -> String {
        switch apiType {
        case .fullnode:
            if let url = fullnodeConfig?.url { return url }
            guard let url = NetworkEndpoints.fullnodeURL(for: network) else {
                throw AptosError.configurationError(
                    "No fullnode URL configured for network: \(network.rawValue)"
                )
            }
            return url

        case .indexer:
            if let url = indexerConfig?.url { return url }
            guard let url = NetworkEndpoints.indexerURL(for: network) else {
                throw AptosError.configurationError(
                    "No indexer URL configured for network: \(network.rawValue)"
                )
            }
            return url

        case .faucet:
            if let url = faucetConfig?.url { return url }
            guard let url = NetworkEndpoints.faucetURL(for: network) else {
                throw AptosError.configurationError(
                    "No faucet URL configured for network: \(network.rawValue)"
                )
            }
            return url

        case .pepper:
            if let url = pepperConfig?.url { return url }
            guard let url = NetworkEndpoints.pepperURL(for: network) else {
                throw AptosError.configurationError(
                    "No pepper service URL configured for network: \(network.rawValue)"
                )
            }
            return url

        case .prover:
            if let url = proverConfig?.url { return url }
            guard let url = NetworkEndpoints.proverURL(for: network) else {
                throw AptosError.configurationError(
                    "No prover service URL configured for network: \(network.rawValue)"
                )
            }
            return url
        }
    }
}
