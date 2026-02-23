import Foundation

// MARK: - FaucetAPI

/// Faucet operations for test networks (devnet, localnet).
///
/// The faucet funds accounts with test APT for development and testing.
/// Not available on mainnet or testnet (testnet uses a separate funding mechanism).
public struct FaucetAPI: Sendable {
    private let config: AptosConfig
    private let client: AptosHTTPClient

    init(config: AptosConfig, client: AptosHTTPClient) {
        self.config = config
        self.client = client
    }

    /// Funds an account with test tokens.
    ///
    /// - Parameters:
    ///   - address: The account address to fund.
    ///   - amount: Amount in octas (default: 100,000,000 = 1 APT).
    /// - Returns: The faucet response confirming the funding transaction.
    public func fundAccount(
        _ address: AccountAddress,
        amount: UInt64 = 100_000_000
    ) async throws -> FaucetResponse {
        let url = try config.getFaucetURL()
        let body = FaucetFundRequest(address: address.toHex(), amount: amount)
        return try await client.post(url: url, path: "fund", body: body, apiType: .faucet)
    }

    /// Creates a new Ed25519 account and funds it with test tokens.
    ///
    /// - Parameter amount: Amount in octas to fund (default: 100,000,000 = 1 APT).
    /// - Returns: The newly created and funded Ed25519 account.
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
