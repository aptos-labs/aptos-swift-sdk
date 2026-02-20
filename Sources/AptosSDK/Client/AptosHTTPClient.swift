import Foundation

/// HTTP client actor for Aptos API communication.
///
/// Manages URLSession, request construction, header injection, and error handling.
public actor AptosHTTPClient {
    private let session: URLSession
    private let config: AptosConfig
    private let jsonDecoder: JSONDecoder
    private let jsonEncoder: JSONEncoder

    public init(config: AptosConfig) {
        self.config = config

        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: sessionConfig)

        self.jsonDecoder = JSONDecoder()
        jsonDecoder.keyDecodingStrategy = .convertFromSnakeCase

        self.jsonEncoder = JSONEncoder()
        jsonEncoder.keyEncodingStrategy = .convertToSnakeCase
    }

    // MARK: - Public API

    /// Execute a GET request to the full node.
    public func get<T: Decodable & Sendable>(
        path: String,
        params: [String: String]? = nil,
        originMethod: String? = nil
    ) async throws -> AptosResponse<T> {
        let url = try buildURL(apiType: .fullnode, path: path, params: params)
        let request = buildRequest(
            url: url,
            method: .get,
            apiType: .fullnode,
            originMethod: originMethod
        )
        return try await execute(request)
    }

    /// Execute a POST request with JSON body to the full node.
    public func post<Req: Encodable & Sendable, Res: Decodable & Sendable>(
        path: String,
        body: Req,
        originMethod: String? = nil
    ) async throws -> AptosResponse<Res> {
        let url = try buildURL(apiType: .fullnode, path: path)
        let bodyData = try jsonEncoder.encode(body)
        let request = buildRequest(
            url: url,
            method: .post,
            body: bodyData,
            contentType: .json,
            apiType: .fullnode,
            originMethod: originMethod
        )
        return try await execute(request)
    }

    /// Execute a POST request with BCS body to the full node.
    public func postBCS<Res: Decodable & Sendable>(
        path: String,
        body: Data,
        contentType: MIMEType = .bcsSignedTransaction,
        originMethod: String? = nil
    ) async throws -> AptosResponse<Res> {
        let url = try buildURL(apiType: .fullnode, path: path)
        let request = buildRequest(
            url: url,
            method: .post,
            body: body,
            contentType: contentType,
            apiType: .fullnode,
            originMethod: originMethod
        )
        return try await execute(request)
    }

    /// Execute a POST request to the indexer (GraphQL).
    public func postIndexer<Res: Decodable & Sendable>(
        body: GraphQLRequest,
        originMethod: String? = nil
    ) async throws -> AptosResponse<Res> {
        let url = try buildURL(apiType: .indexer)
        let bodyData = try jsonEncoder.encode(body)
        let request = buildRequest(
            url: url,
            method: .post,
            body: bodyData,
            contentType: .json,
            apiType: .indexer,
            originMethod: originMethod
        )
        return try await execute(request)
    }

    /// Execute a POST request to the faucet.
    public func postFaucet<Res: Decodable & Sendable>(
        path: String = "/fund",
        body: some Encodable & Sendable,
        originMethod: String? = nil
    ) async throws -> AptosResponse<Res> {
        let url = try buildURL(apiType: .faucet, path: path)
        let bodyData = try jsonEncoder.encode(body)
        // Faucet: strip API_KEY, use AUTH_TOKEN if configured
        var request = buildRequest(
            url: url,
            method: .post,
            body: bodyData,
            contentType: .json,
            apiType: .faucet,
            originMethod: originMethod
        )
        request.setValue(nil, forHTTPHeaderField: "Authorization")
        if let authToken = config.faucetConfig?.authToken {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }
        return try await execute(request)
    }

    /// Execute a POST request to the pepper service.
    public func postPepper<Req: Encodable & Sendable, Res: Decodable & Sendable>(
        path: String,
        body: Req,
        originMethod: String? = nil
    ) async throws -> AptosResponse<Res> {
        let url = try buildURL(apiType: .pepper, path: path)
        let bodyData = try jsonEncoder.encode(body)
        let request = buildRequest(
            url: url,
            method: .post,
            body: bodyData,
            contentType: .json,
            apiType: .pepper,
            originMethod: originMethod
        )
        return try await execute(request)
    }

    /// Execute a POST request to the prover service.
    public func postProver<Req: Encodable & Sendable, Res: Decodable & Sendable>(
        path: String,
        body: Req,
        originMethod: String? = nil
    ) async throws -> AptosResponse<Res> {
        let url = try buildURL(apiType: .prover, path: path)
        let bodyData = try jsonEncoder.encode(body)
        let request = buildRequest(
            url: url,
            method: .post,
            body: bodyData,
            contentType: .json,
            apiType: .prover,
            originMethod: originMethod
        )
        return try await execute(request)
    }

    // MARK: - Pagination

    /// Collect all pages using cursor-based pagination.
    public func paginateWithCursor<T: Decodable & Sendable>(
        path: String,
        params: [String: String]? = nil,
        originMethod: String? = nil
    ) async throws -> [T] {
        var allResults: [T] = []
        var cursor: String?

        repeat {
            var p = params ?? [:]
            if let c = cursor { p["start"] = c }
            let response: AptosResponse<[T]> = try await get(
                path: path, params: p, originMethod: originMethod
            )
            allResults.append(contentsOf: response.data)
            cursor = response.cursor
        } while cursor != nil

        return allResults
    }

    // MARK: - Internal

    private func buildURL(
        apiType: AptosAPIType,
        path: String? = nil,
        params: [String: String]? = nil
    ) throws -> URL {
        let baseURL = try config.getRequestURL(for: apiType)
        var urlString = baseURL
        if let path { urlString += path }
        guard var components = URLComponents(string: urlString) else {
            throw AptosError.networkError("Invalid URL: \(urlString)")
        }
        if let params, !params.isEmpty {
            components.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = components.url else {
            throw AptosError.networkError("Invalid URL components: \(urlString)")
        }
        return url
    }

    private func buildRequest(
        url: URL,
        method: HTTPMethod,
        body: Data? = nil,
        contentType: MIMEType = .json,
        apiType: AptosAPIType,
        originMethod: String? = nil
    ) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.httpBody = body

        // Standard headers
        request.setValue("aptos-swift-sdk/\(sdkVersion)", forHTTPHeaderField: "x-aptos-client")
        request.setValue(contentType.rawValue, forHTTPHeaderField: "Content-Type")
        if let originMethod {
            request.setValue(originMethod, forHTTPHeaderField: "x-aptos-swift-sdk-origin-method")
        }

        // Client config headers
        if let headers = config.clientConfig?.headers {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }

        // API key
        if apiType != .faucet, let apiKey = config.clientConfig?.apiKey {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        // Per-endpoint headers
        switch apiType {
        case .fullnode:
            if let headers = config.fullnodeConfig?.headers {
                for (key, value) in headers { request.setValue(value, forHTTPHeaderField: key) }
            }
        case .indexer:
            if let headers = config.indexerConfig?.headers {
                for (key, value) in headers { request.setValue(value, forHTTPHeaderField: key) }
            }
        default: break
        }

        return request
    }

    private func execute<T: Decodable & Sendable>(
        _ request: URLRequest
    ) async throws -> AptosResponse<T> {
        let (data, urlResponse) = try await session.data(for: request)

        guard let httpResponse = urlResponse as? HTTPURLResponse else {
            throw AptosError.networkError("Non-HTTP response received")
        }

        let headers: [String: String] = Dictionary(
            uniqueKeysWithValues: httpResponse.allHeaderFields.compactMap {
                key, value -> (String, String)? in
                guard let k = key as? String, let v = value as? String else { return nil }
                return (k.lowercased(), v)
            }
        )

        let status = httpResponse.statusCode

        guard (200 ... 299).contains(status) else {
            let bodyString = String(data: data, encoding: .utf8) ?? "<non-utf8>"
            let traceId = headers["traceparent"].flatMap { tp in
                let parts = tp.split(separator: "-")
                return parts.count >= 2 ? String(parts[1]) : nil
            }
            let apiType = inferAPIType(from: request.url)
            throw AptosAPIError(
                url: request.url?.absoluteString ?? "unknown",
                status: status,
                statusText: HTTPURLResponse.localizedString(forStatusCode: status),
                data: bodyString,
                apiType: apiType,
                traceId: traceId
            )
        }

        let decoded = try jsonDecoder.decode(T.self, from: data)
        return AptosResponse(data: decoded, status: status, headers: headers)
    }

    private func inferAPIType(from url: URL?) -> AptosAPIType {
        guard let urlString = url?.absoluteString else { return .fullnode }
        if urlString.contains("graphql") { return .indexer }
        if urlString.contains("faucet") || urlString.contains("/fund") { return .faucet }
        if urlString.contains("pepper") { return .pepper }
        if urlString.contains("prover") { return .prover }
        return .fullnode
    }
}

/// GraphQL request body.
public struct GraphQLRequest: Encodable, Sendable {
    public let query: String
    public let variables: [String: String]?

    public init(query: String, variables: [String: String]? = nil) {
        self.query = query
        self.variables = variables
    }
}
