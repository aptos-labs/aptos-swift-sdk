import Foundation

/// The main entry point for the Aptos Swift SDK.
///
/// `AptosClient` provides access to all Aptos network functionality
/// through domain-specific API namespaces.
///
/// ```swift
/// let aptos = AptosClient(config: AptosConfig(network: .devnet))
///
/// // Account operations
/// let info = try await aptos.account.getAccountInfo(address: myAddress)
///
/// // Build, sign, and submit a transaction
/// let txn = try await aptos.coin.transferAPTTransaction(
///     sender: account.accountAddress,
///     recipient: recipientAddress,
///     amount: 100_000_000
/// )
/// let pending = try await aptos.transaction.signAndSubmitTransaction(
///     signer: account, transaction: .simple(txn)
/// )
/// let committed = try await aptos.transaction.waitForTransaction(hash: pending.hash)
/// ```
public final class AptosClient: Sendable {
    /// SDK configuration.
    public let config: AptosConfig

    /// The underlying HTTP client.
    public let client: AptosHTTPClient

    /// Account-related API (info, modules, resources, balances).
    public let account: AccountAPI

    /// Account abstraction API.
    public let abstraction: AccountAbstractionAPI

    /// Aptos Names Service API.
    public let ans: ANSAPI

    /// Coin transfer API.
    public let coin: CoinAPI

    /// Digital asset (NFT) API.
    public let digitalAsset: DigitalAssetAPI

    /// Faucet API for test networks.
    public let faucet: FaucetAPI

    /// Fungible asset API.
    public let fungibleAsset: FungibleAssetAPI

    /// General API (ledger info, chain ID, view functions).
    public let general: GeneralAPI

    /// Keyless authentication API.
    public let keyless: KeylessAPI

    /// Object API.
    public let object: ObjectAPI

    /// Staking API.
    public let staking: StakingAPI

    /// Table API.
    public let table: TableAPI

    /// Transaction building, signing, submission, and querying API.
    public let transaction: TransactionAPI

    /// Create a new Aptos client.
    ///
    /// - Parameter config: The SDK configuration. Defaults to devnet.
    public init(config: AptosConfig = AptosConfig()) {
        self.config = config
        self.client = AptosHTTPClient(config: config)

        self.account = AccountAPI(config: config, client: client)
        self.abstraction = AccountAbstractionAPI(config: config, client: client)
        self.ans = ANSAPI(config: config, client: client)
        self.coin = CoinAPI(config: config, client: client)
        self.digitalAsset = DigitalAssetAPI(config: config, client: client)
        self.faucet = FaucetAPI(config: config, client: client)
        self.fungibleAsset = FungibleAssetAPI(config: config, client: client)
        self.general = GeneralAPI(config: config, client: client)
        self.keyless = KeylessAPI(config: config, client: client)
        self.object = ObjectAPI(config: config, client: client)
        self.staking = StakingAPI(config: config, client: client)
        self.table = TableAPI(config: config, client: client)
        self.transaction = TransactionAPI(config: config, client: client)
    }
}

// MARK: - Convenience Methods

extension AptosClient {
    /// Sign and submit a transaction, then wait for it to be committed.
    ///
    /// This is a convenience method that combines signing, submission, and waiting.
    public func signSubmitAndWaitForTransaction(
        signer: any AptosAccount,
        transaction: AnyRawTransaction,
        feePayer: (any AptosAccount)? = nil,
        waitOptions: WaitForTransactionOptions? = nil
    ) async throws -> CommittedTransactionResponse {
        let pending = try await self.transaction.signAndSubmitTransaction(
            signer: signer,
            transaction: transaction,
            feePayer: feePayer
        )
        return try await self.transaction.waitForTransaction(
            hash: pending.hash,
            options: waitOptions
        )
    }

    /// Fund an account with test tokens (devnet/testnet only) and wait for the transaction.
    public func fundAccount(
        address: AccountAddress,
        amount: UInt64 = 100_000_000
    ) async throws {
        let result = try await faucet.fundAccount(address: address, amount: amount)
        for hash in result.txnHashes {
            _ = try await self.transaction.waitForTransaction(hash: hash)
        }
    }
}
