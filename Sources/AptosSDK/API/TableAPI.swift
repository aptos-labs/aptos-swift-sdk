import Foundation

/// Table-related API operations.
public struct TableAPI: Sendable {
    private let config: AptosConfig
    private let client: AptosHTTPClient

    public init(config: AptosConfig, client: AptosHTTPClient) {
        self.config = config
        self.client = client
    }

    /// Get a table item by key.
    public func getTableItem<T: Decodable & Sendable>(
        handle: String,
        data: TableItemRequest,
        ledgerVersion: String? = nil
    ) async throws -> T {
        var params: [String: String] = [:]
        if let v = ledgerVersion { params["ledger_version"] = v }
        let response: AptosResponse<T> = try await client.post(
            path: "/tables/\(handle)/item",
            body: data,
            originMethod: "TableAPI.getTableItem"
        )
        return response.data
    }

    /// Get table items data via indexer.
    public func getTableItemsData(
        tableHandle: String,
        options: PaginationOptions? = nil
    ) async throws -> [TableItemData] {
        let query = """
        query GetTableItemsData($tableHandle: String, $limit: Int, $offset: Int) {
            table_items(
                where: { table_handle: { _eq: $tableHandle } }
                limit: $limit
                offset: $offset
            ) {
                decoded_key
                decoded_value
                key
                transaction_version
            }
        }
        """
        var variables: [String: String] = ["tableHandle": tableHandle]
        if let limit = options?.limit { variables["limit"] = String(limit) }
        if let offset = options?.offset { variables["offset"] = String(offset) }

        let result: AptosResponse<IndexerTableItemsResponse> = try await client.postIndexer(
            body: GraphQLRequest(query: query, variables: variables),
            originMethod: "TableAPI.getTableItemsData"
        )
        return result.data.tableItems
    }
}

// MARK: - Response Types

struct IndexerTableItemsResponse: Codable, Sendable {
    let tableItems: [TableItemData]
}

public struct TableItemData: Codable, Sendable {
    public let decodedKey: AnyCodable
    public let decodedValue: AnyCodable
    public let key: String
    public let transactionVersion: UInt64
}
