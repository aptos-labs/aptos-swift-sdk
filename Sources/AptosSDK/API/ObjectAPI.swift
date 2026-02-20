import Foundation

/// Object-related API operations.
public struct ObjectAPI: Sendable {
    private let config: AptosConfig
    private let client: AptosHTTPClient

    public init(config: AptosConfig, client: AptosHTTPClient) {
        self.config = config
        self.client = client
    }

    /// Get object data by object address using the ObjectCore resource.
    public func getObjectDataByObjectAddress(
        objectAddress: AccountAddress,
        minimumLedgerVersion: UInt64? = nil
    ) async throws -> AccountResource {
        let account = AccountAPI(config: config, client: client)
        return try await account.getAccountResource(
            address: objectAddress,
            resourceType: "0x1::object::ObjectCore"
        )
    }
}
