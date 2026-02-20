import Foundation

/// Configuration for an HTTP request to the Aptos API.
public struct AptosRequest: Sendable {
    public let url: URL
    public let method: HTTPMethod
    public let body: Data?
    public let contentType: MIMEType
    public let headers: [String: String]
    public let originMethod: String?

    public init(
        url: URL,
        method: HTTPMethod = .get,
        body: Data? = nil,
        contentType: MIMEType = .json,
        headers: [String: String] = [:],
        originMethod: String? = nil
    ) {
        self.url = url
        self.method = method
        self.body = body
        self.contentType = contentType
        self.headers = headers
        self.originMethod = originMethod
    }
}

/// HTTP methods used by the SDK.
public enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
}
