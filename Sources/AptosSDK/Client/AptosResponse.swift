import Foundation

/// A response from the Aptos API.
public struct AptosResponse<T: Sendable>: Sendable {
    public let data: T
    public let status: Int
    public let headers: [String: String]

    /// Opaque cursor from `x-aptos-cursor` response header for pagination.
    public var cursor: String? {
        headers["x-aptos-cursor"]
    }

    /// Trace ID from the `traceparent` response header.
    public var traceId: String? {
        guard let traceparent = headers["traceparent"] else { return nil }
        let parts = traceparent.split(separator: "-")
        return parts.count >= 2 ? String(parts[1]) : nil
    }
}
