import Foundation

// MARK: - AptosConfig

/// Configuration for the Aptos SDK client.
public struct AptosConfig: Sendable {
    /// The network to connect to.
    public let network: Network

    /// Custom full node REST API URL (overrides network default).
    public let fullnodeURL: String?

    /// Custom faucet URL (overrides network default).
    public let faucetURL: String?

    /// Custom indexer GraphQL URL (overrides network default).
    public let indexerURL: String?

    /// Custom pepper service URL.
    public let pepperURL: String?

    /// Custom prover service URL.
    public let proverURL: String?

    /// Client-wide configuration.
    public let clientConfig: ClientConfig

    /// Additional headers for full node requests.
    public let fullnodeHeaders: [String: String]

    /// Additional headers for indexer requests.
    public let indexerHeaders: [String: String]

    /// Faucet configuration.
    public let faucetConfig: FaucetConfig

    /// Transaction generation defaults.
    public let transactionConfig: TransactionGenerationConfig

    /// Creates a new configuration.
    public init(
        network: Network = .devnet,
        fullnodeURL: String? = nil,
        faucetURL: String? = nil,
        indexerURL: String? = nil,
        pepperURL: String? = nil,
        proverURL: String? = nil,
        clientConfig: ClientConfig = ClientConfig(),
        fullnodeHeaders: [String: String] = [:],
        indexerHeaders: [String: String] = [:],
        faucetConfig: FaucetConfig = FaucetConfig(),
        transactionConfig: TransactionGenerationConfig = TransactionGenerationConfig()
    ) {
        self.network = network
        self.fullnodeURL = fullnodeURL
        self.faucetURL = faucetURL
        self.indexerURL = indexerURL
        self.pepperURL = pepperURL
        self.proverURL = proverURL
        self.clientConfig = clientConfig
        self.fullnodeHeaders = fullnodeHeaders
        self.indexerHeaders = indexerHeaders
        self.faucetConfig = faucetConfig
        self.transactionConfig = transactionConfig
    }

    // MARK: - Convenience Initializers

    /// Creates a mainnet configuration.
    public static func mainnet(clientConfig: ClientConfig = ClientConfig()) -> Self {
        Self(network: .mainnet, clientConfig: clientConfig)
    }

    /// Creates a testnet configuration.
    public static func testnet(clientConfig: ClientConfig = ClientConfig()) -> Self {
        Self(network: .testnet, clientConfig: clientConfig)
    }

    /// Creates a devnet configuration.
    public static func devnet(clientConfig: ClientConfig = ClientConfig()) -> Self {
        Self(network: .devnet, clientConfig: clientConfig)
    }

    /// Creates a local network configuration.
    public static func localnet(clientConfig: ClientConfig = ClientConfig()) -> Self {
        Self(network: .local, clientConfig: clientConfig)
    }

    // MARK: - URL Resolution

    /// Resolves the full node URL for this configuration.
    public func getFullnodeURL() throws -> String {
        if let custom = fullnodeURL { return custom }
        guard let url = Endpoints.fullnodeURL(for: network) else {
            throw AptosError.invalidArgument("No full node URL for network: \(network)")
        }
        return url
    }

    /// Resolves the faucet URL for this configuration.
    public func getFaucetURL() throws -> String {
        if let custom = faucetURL { return custom }
        guard let url = Endpoints.faucetURL(for: network) else {
            throw AptosError.invalidArgument("Faucet not available for network: \(network)")
        }
        return url
    }

    /// Resolves the indexer URL for this configuration.
    public func getIndexerURL() throws -> String {
        if let custom = indexerURL { return custom }
        guard let url = Endpoints.indexerURL(for: network) else {
            throw AptosError.invalidArgument("No indexer URL for network: \(network)")
        }
        return url
    }

    /// Resolves the pepper service URL.
    public func getPepperURL() throws -> String {
        if let custom = pepperURL { return custom }
        guard let url = Endpoints.pepperServiceURL(for: network) else {
            throw AptosError.invalidArgument("No pepper service URL for network: \(network)")
        }
        return url
    }

    /// Resolves the prover service URL.
    public func getProverURL() throws -> String {
        if let custom = proverURL { return custom }
        guard let url = Endpoints.proverServiceURL(for: network) else {
            throw AptosError.invalidArgument("No prover service URL for network: \(network)")
        }
        return url
    }
}

// MARK: - ClientConfig

/// Client-wide HTTP configuration.
public struct ClientConfig: Sendable {
    /// API key for authorization.
    public let apiKey: String?

    /// Additional HTTP headers.
    public let headers: [String: String]

    /// Request timeout interval in seconds.
    public let timeoutInterval: TimeInterval

    public init(
        apiKey: String? = nil,
        headers: [String: String] = [:],
        timeoutInterval: TimeInterval = 30
    ) {
        self.apiKey = apiKey
        self.headers = headers
        self.timeoutInterval = timeoutInterval
    }
}

// MARK: - FaucetConfig

/// Faucet-specific configuration.
public struct FaucetConfig: Sendable {
    /// Auth token for the faucet service.
    public let authToken: String?

    /// Additional faucet headers.
    public let headers: [String: String]

    public init(authToken: String? = nil, headers: [String: String] = [:]) {
        self.authToken = authToken
        self.headers = headers
    }
}

// MARK: - TransactionGenerationConfig

/// Transaction generation defaults.
public struct TransactionGenerationConfig: Sendable {
    /// Default max gas amount.
    public let defaultMaxGasAmount: UInt64

    /// Default transaction expiry in seconds from now.
    public let defaultTxnExpirySecs: UInt64

    public init(
        defaultMaxGasAmount: UInt64 = AptosConstants.defaultMaxGasAmount,
        defaultTxnExpirySecs: UInt64 = AptosConstants.defaultTxnExpirySecs
    ) {
        self.defaultMaxGasAmount = defaultMaxGasAmount
        self.defaultTxnExpirySecs = defaultTxnExpirySecs
    }
}
