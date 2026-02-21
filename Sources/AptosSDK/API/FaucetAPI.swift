import Foundation

// MARK: - FaucetAPI

/// Faucet operations for test networks.
public struct FaucetAPI: Sendable {
    private let config: AptosConfig
    private let client: AptosHTTPClient

    init(config: AptosConfig, client: AptosHTTPClient) {
        self.config = config
        self.client = client
    }

    /// Funds an account with test tokens.
    public func fundAccount(
        _ address: AccountAddress,
        amount: UInt64 = 100_000_000
    ) async throws -> FaucetResponse {
        let url = try config.getFaucetURL()
        let body = FaucetFundRequest(address: address.toHex(), amount: amount)
        return try await client.post(url: url, path: "fund", body: body, apiType: .faucet)
    }

    /// Creates a new Ed25519 account and funds it with test tokens.
    public func createAndFundAccount(amount: UInt64 = 100_000_000) async throws -> Ed25519Account {
        let account = try Ed25519Account.generate()
        _ = try await fundAccount(account.accountAddress, amount: amount)
        return account
    }
}

// MARK: - FaucetFundRequest

private struct FaucetFundRequest: Encodable {
    let address: String
    let amount: UInt64
}
