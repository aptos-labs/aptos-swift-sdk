import Foundation

/// Faucet API for funding accounts on devnet/testnet.
public struct FaucetAPI: Sendable {
    private let config: AptosConfig
    private let client: AptosHTTPClient

    public init(config: AptosConfig, client: AptosHTTPClient) {
        self.config = config
        self.client = client
    }

    /// Fund an account with test APT tokens.
    ///
    /// - Parameters:
    ///   - address: The account address to fund.
    ///   - amount: The amount of APT (in octas) to fund. Defaults to 100_000_000 (1 APT).
    /// - Returns: The transaction hashes from the faucet.
    public func fundAccount(
        address: AccountAddress,
        amount: UInt64 = 100_000_000
    ) async throws -> FaucetFundResponse {
        let body = FaucetFundRequest(
            address: address.toString(),
            amount: amount
        )
        let response: AptosResponse<FaucetFundResponse> = try await client.postFaucet(
            body: body,
            originMethod: "FaucetAPI.fundAccount"
        )
        return response.data
    }
}
