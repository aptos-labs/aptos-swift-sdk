import Foundation

/// Account abstraction API operations.
public struct AccountAbstractionAPI: Sendable {
    private let config: AptosConfig
    private let client: AptosHTTPClient

    public init(config: AptosConfig, client: AptosHTTPClient) {
        self.config = config
        self.client = client
    }

    /// Check if account abstraction is enabled for an account with a specific authentication function.
    public func isAccountAbstractionEnabled(
        accountAddress: AccountAddress,
        authFunction: String
    ) async throws -> Bool {
        let general = GeneralAPI(config: config, client: client)
        let result = try await general.viewJson(
            payload: ViewRequest(
                function: "0x1::account_abstraction::is_abstraction_enabled",
                typeArguments: [],
                arguments: [
                    AnyCodable(accountAddress.toString()),
                    AnyCodable(authFunction),
                ]
            )
        )
        guard let enabled = result.first?.value as? Bool else {
            return false
        }
        return enabled
    }

    /// Build a transaction to enable an authentication function for account abstraction.
    public func addAuthenticationFunction(
        sender: AccountAddress,
        authFunction: String,
        options: TransactionOptions? = nil
    ) async throws -> SimpleTransaction {
        let parts = authFunction.components(separatedBy: "::")
        guard parts.count == 3 else {
            throw AptosError.invalidArgument(
                "authFunction must be 'address::module::function', got: \(authFunction)"
            )
        }

        let data = InputEntryFunctionData(
            function: "0x1::account_abstraction::add_authentication_function",
            functionArguments: [
                AnyEncodable(parts[0]),  // module address
                AnyEncodable(parts[1]),  // module name
                AnyEncodable(parts[2]),  // function name
            ]
        )

        let builder = TransactionBuilder(config: config, client: client)
        return try await builder.buildSimple(sender: sender, data: data, options: options)
    }

    /// Build a transaction to remove an authentication function for account abstraction.
    public func removeAuthenticationFunction(
        sender: AccountAddress,
        authFunction: String,
        options: TransactionOptions? = nil
    ) async throws -> SimpleTransaction {
        let parts = authFunction.components(separatedBy: "::")
        guard parts.count == 3 else {
            throw AptosError.invalidArgument(
                "authFunction must be 'address::module::function', got: \(authFunction)"
            )
        }

        let data = InputEntryFunctionData(
            function: "0x1::account_abstraction::remove_authentication_function",
            functionArguments: [
                AnyEncodable(parts[0]),
                AnyEncodable(parts[1]),
                AnyEncodable(parts[2]),
            ]
        )

        let builder = TransactionBuilder(config: config, client: client)
        return try await builder.buildSimple(sender: sender, data: data, options: options)
    }

    /// Build a transaction to remove all dispatchable authentication functions.
    public func removeAllAuthenticationFunctions(
        sender: AccountAddress,
        options: TransactionOptions? = nil
    ) async throws -> SimpleTransaction {
        let data = InputEntryFunctionData(
            function: "0x1::account_abstraction::remove_all_authentication_functions"
        )

        let builder = TransactionBuilder(config: config, client: client)
        return try await builder.buildSimple(sender: sender, data: data, options: options)
    }
}
