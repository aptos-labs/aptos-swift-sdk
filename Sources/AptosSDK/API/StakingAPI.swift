import Foundation

/// Staking and delegation operations.
public struct StakingAPI: Sendable {
    private let config: AptosConfig
    private let client: AptosHTTPClient
    private let viewAPI: ViewAPI

    init(config: AptosConfig, client: AptosHTTPClient) {
        self.config = config
        self.client = client
        viewAPI = ViewAPI(config: config, client: client)
    }

    /// Gets the current staking pool for a validator.
    public func getStakePool(_ address: AccountAddress) async throws -> AccountResource {
        let accountAPI = AccountAPI(config: config, client: client)
        return try await accountAPI.getAccountResource(address, resourceType: "0x1::stake::StakePool")
    }

    /// Gets delegation pool information.
    public func getDelegationPool(_ poolAddress: AccountAddress) async throws -> AccountResource {
        let accountAPI = AccountAPI(config: config, client: client)
        return try await accountAPI.getAccountResource(
            poolAddress, resourceType: "0x1::delegation_pool::DelegationPool"
        )
    }
}
