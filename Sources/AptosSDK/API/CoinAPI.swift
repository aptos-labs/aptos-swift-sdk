import Foundation

/// Coin-related API operations.
public struct CoinAPI: Sendable {
    private let config: AptosConfig
    private let client: AptosHTTPClient

    public init(config: AptosConfig, client: AptosHTTPClient) {
        self.config = config
        self.client = client
    }

    /// Build a transaction to transfer APT coins.
    public func transferCoinTransaction(
        sender: AccountAddress,
        recipient: AccountAddress,
        amount: UInt64,
        coinType: String = aptosCoin,
        options: TransactionOptions? = nil
    ) async throws -> SimpleTransaction {
        var serializer = Serializer()
        recipient.serialize(to: &serializer)
        let recipientArg = serializer.output()

        var serializer2 = Serializer()
        serializer2.serializeU64(amount)
        let amountArg = serializer2.output()

        let data = InputEntryFunctionData(
            function: "0x1::aptos_account::transfer_coins",
            functionArguments: [AnyEncodable(recipient), AnyEncodable(amount)],
            typeArguments: [coinType],
            abi: EntryFunctionABI(parameters: [.address, .u64])
        )

        let builder = TransactionBuilder(config: config, client: client)
        return try await builder.buildSimple(
            sender: sender,
            data: data,
            options: options
        )
    }

    /// Build a transaction to transfer APT (native transfer).
    public func transferAPTTransaction(
        sender: AccountAddress,
        recipient: AccountAddress,
        amount: UInt64,
        options: TransactionOptions? = nil
    ) async throws -> SimpleTransaction {
        let data = InputEntryFunctionData(
            function: "0x1::aptos_account::transfer",
            functionArguments: [AnyEncodable(recipient), AnyEncodable(amount)],
            typeArguments: [],
            abi: EntryFunctionABI(parameters: [.address, .u64])
        )

        let builder = TransactionBuilder(config: config, client: client)
        return try await builder.buildSimple(
            sender: sender,
            data: data,
            options: options
        )
    }
}
