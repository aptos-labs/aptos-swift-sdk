import Foundation

/// Table state queries.
public struct TableAPI: Sendable {
    private let config: AptosConfig
    private let client: AptosHTTPClient

    init(config: AptosConfig, client: AptosHTTPClient) {
        self.config = config
        self.client = client
    }

    /// Gets a table item.
    public func getTableItem(
        tableHandle: String,
        keyType: String,
        valueType: String,
        key: AnyCodable
    ) async throws -> AnyCodable {
        let url = try config.getFullnodeURL()
        let body = TableItemRequest(keyType: keyType, valueType: valueType, key: key)
        return try await client.post(url: url, path: "tables/\(tableHandle)/item", body: body)
    }
}

private struct TableItemRequest: Encodable {
    let keyType: String
    let valueType: String
    let key: AnyCodable

    enum CodingKeys: String, CodingKey {
        case keyType = "key_type"
        case valueType = "value_type"
        case key
    }
}
