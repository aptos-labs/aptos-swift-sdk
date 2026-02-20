import Foundation

/// Aptos Name Service (ANS) operations.
public struct ANSAPI: Sendable {
    private let config: AptosConfig
    private let client: AptosHTTPClient
    private let viewAPI: ViewAPI

    init(config: AptosConfig, client: AptosHTTPClient) {
        self.config = config
        self.client = client
        self.viewAPI = ViewAPI(config: config, client: client)
    }

    /// Looks up the primary name for an address.
    public func getPrimaryName(_ address: AccountAddress) async throws -> String? {
        let result = try await viewAPI.view(
            function: "0x1::ans::get_primary_name",
            arguments: [address.toHex()]
        )
        guard let first = result.first, let name = first.value as? String else {
            return nil
        }
        return name.isEmpty ? nil : name
    }

    /// Resolves a name to an address.
    public func resolveAddress(_ name: String) async throws -> AccountAddress? {
        let result = try await viewAPI.view(
            function: "0x1::ans::resolve_address",
            arguments: [name]
        )
        guard let first = result.first, let addrStr = first.value as? String else {
            return nil
        }
        return try? AccountAddress.fromHex(addrStr)
    }
}
