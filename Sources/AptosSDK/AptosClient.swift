import Foundation

/// The primary entry point for the Aptos Swift SDK.
///
/// `AptosClient` composes all domain-specific APIs into a unified interface.
///
/// Usage:
/// ```swift
/// let client = AptosClient(.testnet)
/// let balance = try await client.coin.getBalance(address)
/// ```
public struct AptosClient: Sendable {
    /// The configuration used by this client.
    public let config: AptosConfig

    /// Account-related operations.
    public let account: AccountAPI

    /// Transaction building, signing, submission, and querying.
    public let transaction: TransactionAPI

    /// General blockchain queries (ledger info, gas, blocks).
    public let general: GeneralAPI

    /// View function execution.
    public let view: ViewAPI

    /// Coin (APT) transfer and balance operations.
    public let coin: CoinAPI

    /// Digital asset (NFT) operations.
    public let digitalAsset: DigitalAssetAPI

    /// Fungible asset operations.
    public let fungibleAsset: FungibleAssetAPI

    /// Aptos Name Service operations.
    public let ans: ANSAPI

    /// Staking and delegation operations.
    public let staking: StakingAPI

    /// Faucet operations (test networks only).
    public let faucet: FaucetAPI

    /// Object queries.
    public let object: ObjectAPI

    /// Table state queries.
    public let table: TableAPI

    /// Event queries.
    public let event: EventAPI

    /// Keyless authentication operations.
    public let keyless: KeylessAPI

    /// Indexer (GraphQL) queries.
    public let indexer: IndexerClient

    /// Creates a new AptosClient with the given configuration.
    public init(_ config: AptosConfig) {
        self.config = config
        let client = AptosHTTPClient(config: config)

        self.account = AccountAPI(config: config, client: client)
        self.transaction = TransactionAPI(config: config, client: client)
        self.general = GeneralAPI(config: config, client: client)
        self.view = ViewAPI(config: config, client: client)
        self.coin = CoinAPI(config: config, client: client)
        self.digitalAsset = DigitalAssetAPI(config: config, client: client)
        self.fungibleAsset = FungibleAssetAPI(config: config, client: client)
        self.ans = ANSAPI(config: config, client: client)
        self.staking = StakingAPI(config: config, client: client)
        self.faucet = FaucetAPI(config: config, client: client)
        self.object = ObjectAPI(config: config, client: client)
        self.table = TableAPI(config: config, client: client)
        self.event = EventAPI(config: config, client: client)
        self.keyless = KeylessAPI(config: config, client: client)
        self.indexer = IndexerClient(config: config, client: client)
    }

    /// Creates a new AptosClient for the given network.
    public init(_ network: Network) {
        self.init(AptosConfig(network: network))
    }
}
