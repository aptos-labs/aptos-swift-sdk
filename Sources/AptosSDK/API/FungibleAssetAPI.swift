import Foundation

/// Fungible asset operations.
public struct FungibleAssetAPI: Sendable {
    private let config: AptosConfig
    private let client: AptosHTTPClient
    private let viewAPI: ViewAPI

    init(config: AptosConfig, client: AptosHTTPClient) {
        self.config = config
        self.client = client
        viewAPI = ViewAPI(config: config, client: client)
    }

    /// Gets the fungible asset balance for an account at a given metadata address.
    public func getBalance(
        _ address: AccountAddress,
        metadataAddress: String = AptosConstants.aptosFAAddress
    ) async throws -> UInt64 {
        let result = try await viewAPI.view(
            function: "0x1::primary_fungible_store::balance",
            typeArguments: ["0x1::fungible_asset::Metadata"],
            arguments: [address.toHex(), metadataAddress]
        )
        guard let first = result.first, let balStr = first.value as? String,
              let balance = UInt64(balStr)
        else {
            throw AptosError.api(.decodingError("Failed to parse FA balance"))
        }
        return balance
    }
}
