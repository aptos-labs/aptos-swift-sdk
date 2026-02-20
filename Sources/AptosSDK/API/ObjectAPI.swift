import Foundation

/// Object-related queries.
public struct ObjectAPI: Sendable {
    private let config: AptosConfig
    private let client: AptosHTTPClient

    init(config: AptosConfig, client: AptosHTTPClient) {
        self.config = config
        self.client = client
    }

    /// Gets an object resource at the given address.
    public func getObjectResource(
        _ objectAddress: AccountAddress,
        resourceType: String
    ) async throws -> AccountResource {
        let accountAPI = AccountAPI(config: config, client: client)
        return try await accountAPI.getAccountResource(objectAddress, resourceType: resourceType)
    }
}
