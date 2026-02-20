import Foundation

/// General-purpose API for ledger info, chain ID, view functions, and indexer queries.
public struct GeneralAPI: Sendable {
    private let config: AptosConfig
    private let client: AptosHTTPClient

    public init(config: AptosConfig, client: AptosHTTPClient) {
        self.config = config
        self.client = client
    }

    // MARK: - Ledger Info

    /// Get current ledger info.
    public func getLedgerInfo() async throws -> LedgerInfo {
        let response: AptosResponse<LedgerInfo> = try await client.get(
            path: "",
            originMethod: "GeneralAPI.getLedgerInfo"
        )
        return response.data
    }

    /// Get the chain ID.
    public func getChainId() async throws -> UInt8 {
        if let knownId = NetworkEndpoints.chainId(for: config.network) {
            return knownId
        }
        let info = try await getLedgerInfo()
        return info.chainId
    }

    // MARK: - Block

    /// Get a block by height.
    public func getBlockByHeight(
        _ height: UInt64,
        withTransactions: Bool = false
    ) async throws -> Block {
        var params: [String: String] = [:]
        if withTransactions { params["with_transactions"] = "true" }
        let response: AptosResponse<Block> = try await client.get(
            path: "/blocks/by_height/\(height)",
            params: params,
            originMethod: "GeneralAPI.getBlockByHeight"
        )
        return response.data
    }

    /// Get a block by version.
    public func getBlockByVersion(
        _ version: UInt64,
        withTransactions: Bool = false
    ) async throws -> Block {
        var params: [String: String] = [:]
        if withTransactions { params["with_transactions"] = "true" }
        let response: AptosResponse<Block> = try await client.get(
            path: "/blocks/by_version/\(version)",
            params: params,
            originMethod: "GeneralAPI.getBlockByVersion"
        )
        return response.data
    }

    // MARK: - View Functions

    /// Execute a view function using JSON encoding.
    public func viewJson(
        payload: ViewRequest,
        ledgerVersion: String? = nil
    ) async throws -> [AnyCodable] {
        var params: [String: String] = [:]
        if let v = ledgerVersion { params["ledger_version"] = v }
        let response: AptosResponse<[AnyCodable]> = try await client.post(
            path: "/view",
            body: payload,
            originMethod: "GeneralAPI.viewJson"
        )
        return response.data
    }

    /// Execute a view function using BCS encoding.
    public func view(
        functionId: String,
        typeArguments: [TypeTag] = [],
        arguments: [Data] = [],
        ledgerVersion: String? = nil
    ) async throws -> AptosResponse<Data> {
        let ef = try EntryFunction.natural(
            functionId,
            typeArguments: typeArguments,
            arguments: arguments
        )
        let bcsData = ef.bcsToBytes()
        return try await client.postBCS(
            path: "/view",
            body: bcsData,
            contentType: .bcsViewFunction,
            originMethod: "GeneralAPI.view"
        )
    }

    // MARK: - Indexer

    /// Execute a raw GraphQL query against the indexer.
    public func queryIndexer<T: Decodable & Sendable>(
        query: String,
        variables: [String: String]? = nil
    ) async throws -> T {
        let graphqlRequest = GraphQLRequest(query: query, variables: variables)
        let response: AptosResponse<T> = try await client.postIndexer(
            body: graphqlRequest,
            originMethod: "GeneralAPI.queryIndexer"
        )
        return response.data
    }

    // MARK: - Gas Estimation

    /// Get the current gas price estimate.
    public func getGasPriceEstimation() async throws -> GasEstimation {
        let response: AptosResponse<GasEstimation> = try await client.get(
            path: "/estimate_gas_price",
            originMethod: "GeneralAPI.getGasPriceEstimation"
        )
        return response.data
    }
}
