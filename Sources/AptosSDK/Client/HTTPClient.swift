import Foundation

// MARK: - AptosAPIType

/// API type for routing requests to the appropriate service endpoint.
///
/// Each type maps to a different base URL (resolved via ``AptosConfig``) and may
/// use different authentication headers.
public enum AptosAPIType: String, Sendable {
    /// Full node REST API for on-chain reads and transaction submission.
    case fullnode = "Fullnode"
    /// GraphQL indexer API for rich queries over historical and aggregated data.
    case indexer = "Indexer"
    /// Faucet service for funding accounts on test networks.
    case faucet = "Faucet"
    /// Pepper service for keyless authentication.
    case pepper = "Pepper"
    /// Prover service for keyless zero-knowledge proof generation.
    case prover = "Prover"
}

// MARK: - AptosHTTPClient

/// Actor-based HTTP client for Aptos API requests.
///
/// Handles JSON/BCS request encoding, response decoding, authentication headers,
/// and automatic retry with exponential backoff for transient failures (HTTP 429, 5xx, network errors).
/// Thread-safe by construction via Swift's actor model.
public actor AptosHTTPClient {
    private let config: AptosConfig
    private let session: URLSession
    private let retryAfterDateFormatters: [DateFormatter]

    public init(config: AptosConfig) {
        self.config = config
        let urlConfig = URLSessionConfiguration.default
        urlConfig.timeoutIntervalForRequest = config.clientConfig.timeoutInterval
        urlConfig.httpAdditionalHeaders = [
            "User-Agent": AptosConstants.userAgent,
        ]
        session = URLSession(configuration: urlConfig)
        retryAfterDateFormatters = Self.makeRetryAfterDateFormatters()
    }

    // MARK: - JSON Requests

    /// Performs a GET request and decodes the JSON response.
    ///
    /// - Parameters:
    ///   - url: The base URL (e.g., fullnode or indexer URL).
    ///   - path: Path segment appended to the URL.
    ///   - params: Query parameters appended as URL query items.
    ///   - apiType: The API type, used for header selection and routing.
    /// - Returns: The decoded response of type `T`.
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
        return try await executeWithRetry(request)
    }

    /// Performs a POST request with a JSON body and decodes the response.
    ///
    /// - Parameters:
    ///   - url: The base URL.
    ///   - path: Path segment appended to the URL.
    ///   - body: The request body, encoded as JSON.
    ///   - apiType: The API type, used for header selection and routing.
    /// - Returns: The decoded response of type `T`.
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
        return try await executeWithRetry(request)
    }

    /// Performs a POST request with raw BCS bytes, decoding the JSON response.
    ///
    /// - Parameters:
    ///   - url: The base URL.
    ///   - path: Path segment appended to the URL.
    ///   - body: BCS-encoded request body bytes.
    ///   - contentType: MIME type for the request (defaults to signed transaction BCS).
    ///   - apiType: The API type, used for header selection and routing.
    /// - Returns: The decoded response of type `T`.
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
        return try await executeWithRetry(request)
    }

    /// Performs a POST request with raw BCS bytes, returning the response as raw `Data`.
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
        return try await executeRawWithRetry(request)
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

    private func executeWithRetry<T: Decodable>(_ request: URLRequest) async throws -> T {
        let retryConfig = config.retryConfig
        var lastError: Error?

        for attempt in 0 ... retryConfig.maxRetries {
            do {
                let (data, response) = try await session.data(for: request)
                let retryAfter = retryAfterMillis(from: response)
                do {
                    try validateResponse(response, data: data)
                    let decoder = JSONDecoder()
                    decoder.keyDecodingStrategy = .convertFromSnakeCase
                    return try decoder.decode(T.self, from: data)
                } catch let error as AptosError {
                    lastError = error
                    if attempt < retryConfig.maxRetries, isRetryable(error: error) {
                        let delay = retryDelay(
                            attempt: attempt, config: retryConfig,
                            retryAfter: retryAfter
                        )
                        try await Task.sleep(nanoseconds: delay)
                        continue
                    }
                    throw error
                }
            } catch {
                lastError = error
                if attempt < retryConfig.maxRetries, isNetworkError(error) {
                    let delay = retryDelay(attempt: attempt, config: retryConfig)
                    try await Task.sleep(nanoseconds: delay)
                    continue
                }
                throw error
            }
        }

        throw AptosError.network(.retryExhausted(
            "All \(retryConfig.maxRetries) retries exhausted. Last error: \(lastError?.localizedDescription ?? "unknown")"
        ))
    }

    private func executeRawWithRetry(_ request: URLRequest) async throws -> Data {
        let retryConfig = config.retryConfig
        var lastError: Error?

        for attempt in 0 ... retryConfig.maxRetries {
            do {
                let (data, response) = try await session.data(for: request)
                let retryAfter = retryAfterMillis(from: response)
                do {
                    try validateResponse(response, data: data)
                    return data
                } catch let error as AptosError {
                    lastError = error
                    if attempt < retryConfig.maxRetries, isRetryable(error: error) {
                        let delay = retryDelay(
                            attempt: attempt, config: retryConfig,
                            retryAfter: retryAfter
                        )
                        try await Task.sleep(nanoseconds: delay)
                        continue
                    }
                    throw error
                }
            } catch {
                lastError = error
                if attempt < retryConfig.maxRetries, isNetworkError(error) {
                    let delay = retryDelay(attempt: attempt, config: retryConfig)
                    try await Task.sleep(nanoseconds: delay)
                    continue
                }
                throw error
            }
        }

        throw AptosError.network(.retryExhausted(
            "All \(retryConfig.maxRetries) retries exhausted. Last error: \(lastError?.localizedDescription ?? "unknown")"
        ))
    }

    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AptosError.network(.invalidResponse("Non-HTTP response received"))
        }

        let statusCode = httpResponse.statusCode
        guard (200 ..< 300).contains(statusCode) else {
            let message: String = if let errorBody = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                errorBody.message
            } else if let bodyStr = String(data: data, encoding: .utf8) {
                bodyStr
            } else {
                "HTTP \(statusCode)"
            }

            switch statusCode {
            case 401:
                throw AptosError.unauthorized(message)
            case 429:
                throw AptosError.rateLimited(message)
            case 500 ... 599:
                throw AptosError.internalError(message)
            default:
                throw AptosError.network(.httpError(statusCode: statusCode, message: message))
            }
        }
    }

    // MARK: - Retry Helpers

    private func isRetryable(error: AptosError) -> Bool {
        switch error {
        case .rateLimited:
            true
        case .internalError:
            true
        case .network(.timeout), .network(.connectionFailed):
            true
        default:
            false
        }
    }

    private func isNetworkError(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain
    }

    private func retryAfterMillis(from response: URLResponse) -> UInt64? {
        guard let httpResponse = response as? HTTPURLResponse else { return nil }
        guard let headerValue = httpResponse.value(forHTTPHeaderField: "Retry-After") else { return nil }

        let trimmed = headerValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if let seconds = Double(trimmed), seconds >= 0 {
            return clampedRetryAfterMillis(seconds: seconds)
        }

        for formatter in retryAfterDateFormatters {
            if let date = formatter.date(from: trimmed) {
                let secondsUntilRetry = max(0, date.timeIntervalSinceNow)
                return clampedRetryAfterMillis(seconds: secondsUntilRetry)
            }
        }

        return nil
    }

    private func retryDelay(attempt: Int, config: RetryConfig, retryAfter: UInt64? = nil) -> UInt64 {
        if let retryAfter {
            let cappedRetryAfter = min(retryAfter, config.maxDelayMs)
            return cappedRetryAfter * 1_000_000 // ms to ns
        }
        let computedMs = Double(config.initialBackoffMs) * pow(config.backoffMultiplier, Double(attempt))
        let cappedMs = min(computedMs, Double(config.maxDelayMs))
        return UInt64(cappedMs) * 1_000_000 // ms to ns
    }

    private func clampedRetryAfterMillis(seconds: Double) -> UInt64? {
        guard seconds.isFinite, seconds >= 0 else { return nil }
        let millis = seconds * 1000
        guard millis.isFinite, millis >= 0 else { return nil }
        let maxDelayMs = config.retryConfig.maxDelayMs
        let maxMillisAsDouble = min(Double(maxDelayMs), Double(UInt64.max))
        let cappedMillis = min(millis, maxMillisAsDouble)
        if cappedMillis >= Double(UInt64.max) {
            return UInt64.max
        }
        let truncatedMillis = UInt64(cappedMillis.rounded(FloatingPointRoundingRule.down))
        return min(truncatedMillis, maxDelayMs)
    }

    private static func makeRetryAfterDateFormatters() -> [DateFormatter] {
        let formats = [
            "EEE',' dd MMM yyyy HH':'mm':'ss zzz", // IMF-fixdate
            "EEEE',' dd-MMM-yy HH':'mm':'ss zzz", // obsolete RFC 850
            "EEE MMM d HH':'mm':'ss yyyy", // ANSI C's asctime()
        ]
        return formats.map { format in
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = format
            return formatter
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
