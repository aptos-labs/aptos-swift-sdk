import Foundation

/// View function (read-only Move function) execution.
public struct ViewAPI: Sendable {
    private let config: AptosConfig
    private let client: AptosHTTPClient

    init(config: AptosConfig, client: AptosHTTPClient) {
        self.config = config
        self.client = client
    }

    /// Executes a view function and returns the result.
    public func view(
        function: String,
        typeArguments: [String] = [],
        arguments: [Any] = []
    ) async throws -> [AnyCodable] {
        let url = try config.getFullnodeURL()
        let request = ViewRequest(
            function: function,
            typeArguments: typeArguments,
            arguments: arguments.map { AnyCodable($0) }
        )
        return try await client.post(url: url, path: "view", body: request)
    }

    /// Gets the APT balance for an account using a view function.
    public func getBalance(_ address: AccountAddress) async throws -> UInt64 {
        let result = try await view(
            function: "0x1::coin::balance",
            typeArguments: [AptosConstants.aptosCoin],
            arguments: [address.toHex()]
        )
        guard let first = result.first, let balanceStr = first.value as? String,
              let balance = UInt64(balanceStr)
        else {
            throw AptosError.api(.decodingError("Failed to parse balance"))
        }
        return balance
    }
}
