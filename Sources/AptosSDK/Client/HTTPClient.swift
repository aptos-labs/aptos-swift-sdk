import Foundation

// MARK: - AptosAPIType

/// API type for routing requests.
public enum AptosAPIType: String, Sendable {
    case fullnode = "Fullnode"
    case indexer = "Indexer"
    case faucet = "Faucet"
    case pepper = "Pepper"
    case prover = "Prover"
}

// MARK: - AptosHTTPClient

/// Actor-based HTTP client for Aptos API requests.
public actor AptosHTTPClient {
    private let config: AptosConfig
    private let session: URLSession

    public init(config: AptosConfig) {
        self.config = config
        let urlConfig = URLSessionConfiguration.default
        urlConfig.timeoutIntervalForRequest = config.clientConfig.timeoutInterval
        urlConfig.httpAdditionalHeaders = [
            "User-Agent": AptosConstants.userAgent,
        ]
        session = URLSession(configuration: urlConfig)
    }

    // MARK: - JSON Requests

    /// Performs a GET request and decodes the JSON response.
    public func get<T: Decodable & Sendable>(
        url: String,
        path: String = "",
        params: [String: String] = [:],
        apiType: AptosAPIType = .fullnode
    ) async throws -> T {
        let request = try buildRequest(
            url: url, path: path, method: "GET",
            params: params, apiType: apiType
        )
        return try await execute(request)
    }

    /// Performs a POST request with a JSON body and decodes the response.
    public func post<T: Decodable & Sendable>(
        url: String,
        path: String = "",
        body: some Encodable & Sendable,
        apiType: AptosAPIType = .fullnode
    ) async throws -> T {
        var request = try buildRequest(
            url: url, path: path, method: "POST",
            apiType: apiType
        )
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        return try await execute(request)
    }

    /// Performs a POST request with raw BCS bytes.
    public func postBCS<T: Decodable & Sendable>(
        url: String,
        path: String = "",
        body: Data,
        contentType: String = AptosConstants.bcsSignedTransactionMIME,
        apiType: AptosAPIType = .fullnode
    ) async throws -> T {
        var request = try buildRequest(
            url: url, path: path, method: "POST",
            apiType: apiType
        )
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        return try await execute(request)
    }

    /// Performs a POST request with raw BCS bytes, returning raw Data.
    public func postBCSRaw(
        url: String,
        path: String = "",
        body: Data,
        contentType: String = AptosConstants.bcsSignedTransactionMIME
    ) async throws -> Data {
        var request = try buildRequest(
            url: url, path: path, method: "POST",
            apiType: .fullnode
        )
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
        return data
    }

    // MARK: - Internal

    private func buildRequest(
        url: String,
        path: String = "",
        method: String,
        params: [String: String] = [:],
        apiType: AptosAPIType = .fullnode
    ) throws -> URLRequest {
        var fullURL = url
        if !path.isEmpty {
            fullURL = url + (url.hasSuffix("/") ? "" : "/") + path
        }

        guard var components = URLComponents(string: fullURL) else {
            throw AptosError.network(.invalidURL("Invalid URL: \(fullURL)"))
        }

        if !params.isEmpty {
            components.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        }

        guard let finalURL = components.url else {
            throw AptosError.network(.invalidURL("Could not construct URL from: \(fullURL)"))
        }

        var request = URLRequest(url: finalURL)
        request.httpMethod = method

        // Add common headers
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(AptosConstants.userAgent, forHTTPHeaderField: "x-aptos-client")

        // Add API key
        if let apiKey = config.clientConfig.apiKey, apiType != .faucet {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        // Add per-config headers
        for (key, value) in config.clientConfig.headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        // Add API-type specific headers
        switch apiType {
        case .fullnode:
            for (key, value) in config.fullnodeHeaders {
                request.setValue(value, forHTTPHeaderField: key)
            }
        case .indexer:
            for (key, value) in config.indexerHeaders {
                request.setValue(value, forHTTPHeaderField: key)
            }
        case .faucet:
            if let token = config.faucetConfig.authToken {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            for (key, value) in config.faucetConfig.headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        case .pepper, .prover:
            break
        }

        return request
    }

    private func execute<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)

        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(T.self, from: data)
        } catch {
            throw AptosError.api(.decodingError(
                "Failed to decode \(T.self): \(error.localizedDescription)"
            ))
        }
    }

    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AptosError.network(.invalidResponse("Non-HTTP response received"))
        }

        let statusCode = httpResponse.statusCode
        guard (200 ..< 300).contains(statusCode) else {
            // Try to parse error body
            let message: String = if let errorBody = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                errorBody.message
            } else if let bodyStr = String(data: data, encoding: .utf8) {
                bodyStr
            } else {
                "HTTP \(statusCode)"
            }
            throw AptosError.network(.httpError(statusCode: statusCode, message: message))
        }
    }
}

// MARK: - APIErrorResponse

/// API error response body structure.
private struct APIErrorResponse: Decodable {
    let message: String
    let errorCode: String?
    let vmErrorCode: Int?

    enum CodingKeys: String, CodingKey {
        case message
        case errorCode = "error_code"
        case vmErrorCode = "vm_error_code"
    }
}
