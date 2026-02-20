import Foundation

// MARK: - AptosError

/// Top-level error type for the Aptos SDK.
public enum AptosError: Error, Sendable, LocalizedError {
    case parse(ParseError)
    case crypto(CryptoError)
    case serialization(SerializationError)
    case network(NetworkError)
    case api(APIError)
    case transaction(TransactionError)
    case keyless(KeylessError)
    case invalidArgument(String)
    case invalidState(String)
    case notFound(String)
    case timeout(String)
    case unknown(String)

    public var errorDescription: String? {
        switch self {
        case let .parse(e): "Parse error: \(e.localizedDescription)"
        case let .crypto(e): "Crypto error: \(e.localizedDescription)"
        case let .serialization(e): "Serialization error: \(e.localizedDescription)"
        case let .network(e): "Network error: \(e.localizedDescription)"
        case let .api(e): "API error: \(e.localizedDescription)"
        case let .transaction(e): "Transaction error: \(e.localizedDescription)"
        case let .keyless(e): "Keyless error: \(e.localizedDescription)"
        case let .invalidArgument(msg): "Invalid argument: \(msg)"
        case let .invalidState(msg): "Invalid state: \(msg)"
        case let .notFound(msg): "Not found: \(msg)"
        case let .timeout(msg): "Timeout: \(msg)"
        case let .unknown(msg): "Unknown error: \(msg)"
        }
    }
}

// MARK: - ParseError

public enum ParseError: Error, Sendable, LocalizedError {
    case invalidHex(String)
    case invalidAddress(String)
    case invalidTypeTag(String)
    case invalidStructTag(String)
    case invalidModuleId(String)
    case invalidMoveFunction(String)
    case invalidDerivationPath(String)
    case invalidMnemonic(String)

    public var errorDescription: String? {
        switch self {
        case let .invalidHex(msg): "Invalid hex: \(msg)"
        case let .invalidAddress(msg): "Invalid address: \(msg)"
        case let .invalidTypeTag(msg): "Invalid type tag: \(msg)"
        case let .invalidStructTag(msg): "Invalid struct tag: \(msg)"
        case let .invalidModuleId(msg): "Invalid module ID: \(msg)"
        case let .invalidMoveFunction(msg): "Invalid move function: \(msg)"
        case let .invalidDerivationPath(msg): "Invalid derivation path: \(msg)"
        case let .invalidMnemonic(msg): "Invalid mnemonic: \(msg)"
        }
    }
}

// MARK: - CryptoError

public enum CryptoError: Error, Sendable, LocalizedError {
    case invalidKeyLength(expected: Int, actual: Int)
    case invalidSignatureLength(expected: Int, actual: Int)
    case invalidPublicKey(String)
    case invalidPrivateKey(String)
    case invalidSignature(String)
    case signatureFailed(String)
    case verificationFailed(String)
    case invalidSeed(String)
    case unsupportedScheme(String)

    public var errorDescription: String? {
        switch self {
        case let .invalidKeyLength(expected, actual):
            "Invalid key length: expected \(expected), got \(actual)"
        case let .invalidSignatureLength(expected, actual):
            "Invalid signature length: expected \(expected), got \(actual)"
        case let .invalidPublicKey(msg): "Invalid public key: \(msg)"
        case let .invalidPrivateKey(msg): "Invalid private key: \(msg)"
        case let .invalidSignature(msg): "Invalid signature: \(msg)"
        case let .signatureFailed(msg): "Signature failed: \(msg)"
        case let .verificationFailed(msg): "Verification failed: \(msg)"
        case let .invalidSeed(msg): "Invalid seed: \(msg)"
        case let .unsupportedScheme(msg): "Unsupported scheme: \(msg)"
        }
    }
}

// MARK: - SerializationError

public enum SerializationError: Error, Sendable, LocalizedError {
    case outOfRange(String)
    case bufferOverflow(String)
    case unexpectedEnd(String)
    case invalidData(String)
    case maxLengthExceeded(String)
    case depthLimitExceeded(String)
    case remainingBytes(Int)

    public var errorDescription: String? {
        switch self {
        case let .outOfRange(msg): "Out of range: \(msg)"
        case let .bufferOverflow(msg): "Buffer overflow: \(msg)"
        case let .unexpectedEnd(msg): "Unexpected end of data: \(msg)"
        case let .invalidData(msg): "Invalid data: \(msg)"
        case let .maxLengthExceeded(msg): "Max length exceeded: \(msg)"
        case let .depthLimitExceeded(msg): "Depth limit exceeded: \(msg)"
        case let .remainingBytes(count): "Remaining \(count) unconsumed bytes"
        }
    }
}

// MARK: - NetworkError

public enum NetworkError: Error, Sendable, LocalizedError {
    case connectionFailed(String)
    case timeout(String)
    case invalidURL(String)
    case invalidResponse(String)
    case httpError(statusCode: Int, message: String)
    case retryExhausted(String)

    public var errorDescription: String? {
        switch self {
        case let .connectionFailed(msg): "Connection failed: \(msg)"
        case let .timeout(msg): "Timeout: \(msg)"
        case let .invalidURL(msg): "Invalid URL: \(msg)"
        case let .invalidResponse(msg): "Invalid response: \(msg)"
        case let .httpError(code, msg): "HTTP \(code): \(msg)"
        case let .retryExhausted(msg): "Retry exhausted: \(msg)"
        }
    }
}

// MARK: - APIError

public enum APIError: Error, Sendable, LocalizedError {
    case aptosApiError(message: String, errorCode: String?, vmErrorCode: Int?)
    case indexerError(message: String, errors: [String])
    case faucetError(message: String)
    case decodingError(String)

    public var errorDescription: String? {
        switch self {
        case let .aptosApiError(msg, code, vmCode):
            var desc = msg
            if let code { desc += " (code: \(code))" }
            if let vmCode { desc += " (vm_error: \(vmCode))" }
            return desc
        case let .indexerError(msg, errors):
            return "\(msg): \(errors.joined(separator: ", "))"
        case let .faucetError(msg): return "Faucet error: \(msg)"
        case let .decodingError(msg): return "Decoding error: \(msg)"
        }
    }
}

// MARK: - TransactionError

public enum TransactionError: Error, Sendable, LocalizedError {
    case buildFailed(String)
    case signFailed(String)
    case submitFailed(String)
    case simulationFailed(String)
    case waitFailed(String)
    case executionFailed(hash: String, message: String)
    case expired(String)
    case invalidPayload(String)
    case invalidAuthenticator(String)
    case sequenceNumberMismatch(String)

    public var errorDescription: String? {
        switch self {
        case let .buildFailed(msg): "Build failed: \(msg)"
        case let .signFailed(msg): "Sign failed: \(msg)"
        case let .submitFailed(msg): "Submit failed: \(msg)"
        case let .simulationFailed(msg): "Simulation failed: \(msg)"
        case let .waitFailed(msg): "Wait failed: \(msg)"
        case let .executionFailed(hash, msg): "Execution failed (\(hash)): \(msg)"
        case let .expired(msg): "Transaction expired: \(msg)"
        case let .invalidPayload(msg): "Invalid payload: \(msg)"
        case let .invalidAuthenticator(msg): "Invalid authenticator: \(msg)"
        case let .sequenceNumberMismatch(msg): "Sequence number mismatch: \(msg)"
        }
    }
}

// MARK: - KeylessError

public enum KeylessError: Error, Sendable, LocalizedError {
    case invalidJWT(String)
    case pepperServiceError(String)
    case proverServiceError(String)
    case proofExpired(String)
    case invalidEphemeralKeyPair(String)
    case invalidConfiguration(String)

    public var errorDescription: String? {
        switch self {
        case let .invalidJWT(msg): "Invalid JWT: \(msg)"
        case let .pepperServiceError(msg): "Pepper service error: \(msg)"
        case let .proverServiceError(msg): "Prover service error: \(msg)"
        case let .proofExpired(msg): "Proof expired: \(msg)"
        case let .invalidEphemeralKeyPair(msg): "Invalid ephemeral key pair: \(msg)"
        case let .invalidConfiguration(msg): "Invalid configuration: \(msg)"
        }
    }
}
