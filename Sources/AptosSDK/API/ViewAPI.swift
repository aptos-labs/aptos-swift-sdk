import Foundation

/// View function (read-only Move function) execution.
///
/// View functions run on the full node without creating a transaction and return
/// the result directly. Useful for reading on-chain state like balances, resource data, etc.
public struct ViewAPI: Sendable {
    private let config: AptosConfig
    private let client: AptosHTTPClient

    init(config: AptosConfig, client: AptosHTTPClient) {
        self.config = config
        self.client = client
    }

    /// Executes a view function and returns the result.
    ///
    /// - Parameters:
    ///   - function: Fully qualified function name (e.g., `"0x1::coin::balance"`).
    ///   - typeArguments: Move type arguments as strings (e.g., `["0x1::aptos_coin::AptosCoin"]`).
    ///   - arguments: Function arguments matching the view function's parameter types.
    /// - Returns: An array of decoded return values.
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
