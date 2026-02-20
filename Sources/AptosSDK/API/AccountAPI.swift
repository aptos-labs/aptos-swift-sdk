import Foundation

/// Account-related API operations.
public struct AccountAPI: Sendable {
    private let config: AptosConfig
    private let client: AptosHTTPClient

    public init(config: AptosConfig, client: AptosHTTPClient) {
        self.config = config
        self.client = client
    }

    // MARK: - Account Info

    /// Get account data (sequence number and authentication key).
    public func getAccountInfo(address: AccountAddress) async throws -> AccountData {
        let response: AptosResponse<AccountData> = try await client.get(
            path: "/accounts/\(address)",
            originMethod: "AccountAPI.getAccountInfo"
        )
        return response.data
    }

    // MARK: - Modules

    /// Get all modules deployed at an account.
    public func getAccountModules(
        address: AccountAddress,
        options: PaginationOptions? = nil
    ) async throws -> [MoveModuleBytecode] {
        let params = options?.queryParams ?? [:]
        let response: AptosResponse<[MoveModuleBytecode]> = try await client.get(
            path: "/accounts/\(address)/modules",
            params: params.isEmpty ? nil : params,
            originMethod: "AccountAPI.getAccountModules"
        )
        return response.data
    }

    /// Get a specific module by name.
    public func getAccountModule(
        address: AccountAddress,
        moduleName: String,
        ledgerVersion: String? = nil
    ) async throws -> MoveModuleBytecode {
        var params: [String: String] = [:]
        if let v = ledgerVersion { params["ledger_version"] = v }
        let response: AptosResponse<MoveModuleBytecode> = try await client.get(
            path: "/accounts/\(address)/module/\(moduleName)",
            params: params.isEmpty ? nil : params,
            originMethod: "AccountAPI.getAccountModule"
        )
        return response.data
    }

    // MARK: - Resources

    /// Get all resources at an account.
    public func getAccountResources(
        address: AccountAddress,
        options: PaginationOptions? = nil
    ) async throws -> [AccountResource] {
        let params = options?.queryParams ?? [:]
        let response: AptosResponse<[AccountResource]> = try await client.get(
            path: "/accounts/\(address)/resources",
            params: params.isEmpty ? nil : params,
            originMethod: "AccountAPI.getAccountResources"
        )
        return response.data
    }

    /// Get a specific resource by type.
    public func getAccountResource(
        address: AccountAddress,
        resourceType: String,
        ledgerVersion: String? = nil
    ) async throws -> AccountResource {
        var params: [String: String] = [:]
        if let v = ledgerVersion { params["ledger_version"] = v }
        let response: AptosResponse<AccountResource> = try await client.get(
            path: "/accounts/\(address)/resource/\(resourceType)",
            params: params.isEmpty ? nil : params,
            originMethod: "AccountAPI.getAccountResource"
        )
        return response.data
    }

    // MARK: - Transactions

    /// Get transactions for an account.
    public func getAccountTransactions(
        address: AccountAddress,
        options: PaginationOptions? = nil
    ) async throws -> [TransactionResponse] {
        let params = options?.queryParams ?? [:]
        let response: AptosResponse<[TransactionResponse]> = try await client.get(
            path: "/accounts/\(address)/transactions",
            params: params.isEmpty ? nil : params,
            originMethod: "AccountAPI.getAccountTransactions"
        )
        return response.data
    }

    // MARK: - APT Balance

    /// Get the APT balance for an account.
    public func getAccountAPTAmount(address: AccountAddress) async throws -> UInt64 {
        let resource = try await getAccountResource(
            address: address,
            resourceType: "0x1::coin::CoinStore<\(aptosCoin)>"
        )
        guard let data = resource.data as? AnyCodable,
              let dict = data.value as? [String: Any],
              let coin = dict["coin"] as? [String: Any],
              let valueStr = coin["value"] as? String,
              let value = UInt64(valueStr)
        else {
            throw AptosError.internalError("Unable to parse APT balance")
        }
        return value
    }

    /// Get the coin balance for an account (any coin type).
    public func getAccountCoinAmount(
        address: AccountAddress,
        coinType: String = aptosCoin
    ) async throws -> UInt64 {
        let resource = try await getAccountResource(
            address: address,
            resourceType: "0x1::coin::CoinStore<\(coinType)>"
        )
        guard let data = resource.data as? AnyCodable,
              let dict = data.value as? [String: Any],
              let coin = dict["coin"] as? [String: Any],
              let valueStr = coin["value"] as? String,
              let value = UInt64(valueStr)
        else {
            throw AptosError.internalError("Unable to parse coin balance for \(coinType)")
        }
        return value
    }

    // MARK: - Authentication

    /// Look up the current authentication key for an account.
    public func lookupOriginalAccountAddress(
        authKey: String
    ) async throws -> AccountAddress {
        let info = try await getAccountInfo(
            address: try AccountAddress.fromString(authKey)
        )
        return try AccountAddress.fromString(info.authenticationKey)
    }
}
