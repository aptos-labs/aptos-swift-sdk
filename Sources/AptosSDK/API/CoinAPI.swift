import Foundation

/// Coin (APT) transfer and balance operations.
///
/// Provides convenience methods for the most common APT operations.
/// For custom coin types, use ``TransactionAPI`` with an appropriate ``EntryFunction``.
public struct CoinAPI: Sendable {
    private let config: AptosConfig
    private let client: AptosHTTPClient
    private let transactionAPI: TransactionAPI
    private let viewAPI: ViewAPI

    init(config: AptosConfig, client: AptosHTTPClient) {
        self.config = config
        self.client = client
        transactionAPI = TransactionAPI(config: config, client: client)
        viewAPI = ViewAPI(config: config, client: client)
    }

    /// Transfers APT from one account to another.
    ///
    /// - Parameters:
    ///   - sender: The account sending APT (signs the transaction).
    ///   - recipient: The destination account address.
    ///   - amount: Amount to transfer in octas (1 APT = 100,000,000 octas).
    ///   - options: Optional transaction configuration overrides.
    /// - Returns: The confirmed transaction response from the blockchain.
    public func transferAPT(
        from sender: any AptosAccount,
        to recipient: AccountAddress,
        amount: UInt64,
        options: TransactionOptions = TransactionOptions()
    ) async throws -> TransactionResponse {
        let payload = TransactionPayload.entryFunction(
            try EntryFunction.aptTransfer(to: recipient, amount: amount)
        )
        return try await transactionAPI.submitAndWait(
            sender: sender, payload: payload, options: options
        )
    }

    /// Gets the APT balance for an account in octas.
    ///
    /// - Parameter address: The account address to query.
    /// - Returns: The balance in octas (1 APT = 100,000,000 octas).
    public func getBalance(_ address: AccountAddress) async throws -> UInt64 {
        try await viewAPI.getBalance(address)
    }
}
