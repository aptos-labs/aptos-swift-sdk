import Foundation

/// Event queries.
public struct EventAPI: Sendable {
    private let config: AptosConfig
    private let client: AptosHTTPClient

    init(config: AptosConfig, client: AptosHTTPClient) {
        self.config = config
        self.client = client
    }

    /// Gets events by event handle.
    public func getEvents(
        address: AccountAddress,
        eventHandle: String,
        fieldName: String,
        start: UInt64? = nil,
        limit: Int? = nil
    ) async throws -> [EventResponse] {
        let url = try config.getFullnodeURL()
        var params: [String: String] = [:]
        if let start { params["start"] = String(start) }
        if let limit { params["limit"] = String(limit) }
        let path = "accounts/\(address.toHex())/events/\(eventHandle)/\(fieldName)"
        return try await client.get(url: url, path: path, params: params)
    }
}
