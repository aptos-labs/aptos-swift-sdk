import Foundation

/// HTTP API error with full context.
public struct AptosAPIError: Error, Sendable {
    public let url: String
    public let status: Int
    public let statusText: String
    public let data: String
    public let apiType: AptosAPIType
    public let traceId: String?

    public init(
        url: String,
        status: Int,
        statusText: String,
        data: String,
        apiType: AptosAPIType,
        traceId: String? = nil
    ) {
        self.url = url
        self.status = status
        self.statusText = statusText
        self.data = Self.truncateData(data)
        self.apiType = apiType
        self.traceId = traceId
    }

    private static func truncateData(_ data: String) -> String {
        guard data.count > 400 else { return data }
        let prefix = data.prefix(200)
        let suffix = data.suffix(200)
        return "\(prefix)...\(suffix)"
    }
}

extension AptosAPIError: LocalizedError {
    public var errorDescription: String? {
        var msg = "[\(apiType.rawValue)] \(url) - \(status) \(statusText): \(data)"
        if let traceId {
            msg += " (trace: \(traceId))"
        }
        return msg
    }
}
