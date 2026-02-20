import Foundation

/// General blockchain queries.
public struct GeneralAPI: Sendable {
    private let config: AptosConfig
    private let client: AptosHTTPClient

    init(config: AptosConfig, client: AptosHTTPClient) {
        self.config = config
        self.client = client
    }

    /// Gets the current ledger information.
    public func getLedgerInfo() async throws -> LedgerInfo {
        let url = try config.getFullnodeURL()
        return try await client.get(url: url)
    }

    /// Gets the estimated gas price.
    public func estimateGasPrice() async throws -> GasEstimate {
        let url = try config.getFullnodeURL()
        return try await client.get(url: url, path: "estimate_gas_price")
    }

    /// Gets a block by height.
    public func getBlockByHeight(_ height: UInt64, withTransactions: Bool = false) async throws -> Block {
        let url = try config.getFullnodeURL()
        var params: [String: String] = [:]
        if withTransactions { params["with_transactions"] = "true" }
        return try await client.get(url: url, path: "blocks/by_height/\(height)", params: params)
    }

    /// Gets a block by version.
    public func getBlockByVersion(_ version: UInt64, withTransactions: Bool = false) async throws -> Block {
        let url = try config.getFullnodeURL()
        var params: [String: String] = [:]
        if withTransactions { params["with_transactions"] = "true" }
        return try await client.get(url: url, path: "blocks/by_version/\(version)", params: params)
    }

    /// Gets the chain ID.
    public func getChainId() async throws -> UInt8 {
        let info = try await getLedgerInfo()
        return info.chainId
    }
}
