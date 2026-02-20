import Foundation

/// Coin (APT) transfer operations.
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

    /// Gets the APT balance for an account.
    public func getBalance(_ address: AccountAddress) async throws -> UInt64 {
        try await viewAPI.getBalance(address)
    }
}
