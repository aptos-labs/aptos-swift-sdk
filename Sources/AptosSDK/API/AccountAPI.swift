import Foundation

/// Account-related API operations (account data, resources, modules, sequence numbers).
public struct AccountAPI: Sendable {
    private let config: AptosConfig
    private let client: AptosHTTPClient

    init(config: AptosConfig, client: AptosHTTPClient) {
        self.config = config
        self.client = client
    }

    /// Gets account information (sequence number, auth key).
    public func getAccount(_ address: AccountAddress) async throws -> AccountData {
        let url = try config.getFullnodeURL()
        return try await client.get(url: url, path: "accounts/\(address.toHex())")
    }

    /// Gets all resources for an account.
    public func getAccountResources(_ address: AccountAddress) async throws -> [AccountResource] {
        let url = try config.getFullnodeURL()
        return try await client.get(url: url, path: "accounts/\(address.toHex())/resources")
    }

    /// Gets a specific resource for an account.
    public func getAccountResource(
        _ address: AccountAddress,
        resourceType: String
    ) async throws -> AccountResource {
        let url = try config.getFullnodeURL()
        let encodedType = resourceType.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? resourceType
        return try await client.get(url: url, path: "accounts/\(address.toHex())/resource/\(encodedType)")
    }

    /// Gets all modules for an account.
    public func getAccountModules(_ address: AccountAddress) async throws -> [MoveModule] {
        let url = try config.getFullnodeURL()
        return try await client.get(url: url, path: "accounts/\(address.toHex())/modules")
    }

    /// Gets a specific module for an account.
    public func getAccountModule(_ address: AccountAddress, moduleName: String) async throws -> MoveModule {
        let url = try config.getFullnodeURL()
        return try await client.get(url: url, path: "accounts/\(address.toHex())/module/\(moduleName)")
    }

    /// Gets the current sequence number for an account.
    public func getSequenceNumber(_ address: AccountAddress) async throws -> UInt64 {
        let accountData = try await getAccount(address)
        guard let seqNum = UInt64(accountData.sequenceNumber) else {
            throw AptosError.api(.decodingError("Invalid sequence number: \(accountData.sequenceNumber)"))
        }
        return seqNum
    }
}
