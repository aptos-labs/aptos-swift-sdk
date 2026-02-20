import Foundation

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
        case .parse(let e): return "Parse error: \(e.localizedDescription)"
        case .crypto(let e): return "Crypto error: \(e.localizedDescription)"
        case .serialization(let e): return "Serialization error: \(e.localizedDescription)"
        case .network(let e): return "Network error: \(e.localizedDescription)"
        case .api(let e): return "API error: \(e.localizedDescription)"
        case .transaction(let e): return "Transaction error: \(e.localizedDescription)"
        case .keyless(let e): return "Keyless error: \(e.localizedDescription)"
        case .invalidArgument(let msg): return "Invalid argument: \(msg)"
        case .invalidState(let msg): return "Invalid state: \(msg)"
        case .notFound(let msg): return "Not found: \(msg)"
        case .timeout(let msg): return "Timeout: \(msg)"
        case .unknown(let msg): return "Unknown error: \(msg)"
        }
    }
}

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
        case .invalidHex(let msg): return "Invalid hex: \(msg)"
        case .invalidAddress(let msg): return "Invalid address: \(msg)"
        case .invalidTypeTag(let msg): return "Invalid type tag: \(msg)"
        case .invalidStructTag(let msg): return "Invalid struct tag: \(msg)"
        case .invalidModuleId(let msg): return "Invalid module ID: \(msg)"
        case .invalidMoveFunction(let msg): return "Invalid move function: \(msg)"
        case .invalidDerivationPath(let msg): return "Invalid derivation path: \(msg)"
        case .invalidMnemonic(let msg): return "Invalid mnemonic: \(msg)"
        }
    }
}

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
        case .invalidKeyLength(let expected, let actual):
            return "Invalid key length: expected \(expected), got \(actual)"
        case .invalidSignatureLength(let expected, let actual):
            return "Invalid signature length: expected \(expected), got \(actual)"
        case .invalidPublicKey(let msg): return "Invalid public key: \(msg)"
        case .invalidPrivateKey(let msg): return "Invalid private key: \(msg)"
        case .invalidSignature(let msg): return "Invalid signature: \(msg)"
        case .signatureFailed(let msg): return "Signature failed: \(msg)"
        case .verificationFailed(let msg): return "Verification failed: \(msg)"
        case .invalidSeed(let msg): return "Invalid seed: \(msg)"
        case .unsupportedScheme(let msg): return "Unsupported scheme: \(msg)"
        }
    }
}

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
        case .outOfRange(let msg): return "Out of range: \(msg)"
        case .bufferOverflow(let msg): return "Buffer overflow: \(msg)"
        case .unexpectedEnd(let msg): return "Unexpected end of data: \(msg)"
        case .invalidData(let msg): return "Invalid data: \(msg)"
        case .maxLengthExceeded(let msg): return "Max length exceeded: \(msg)"
        case .depthLimitExceeded(let msg): return "Depth limit exceeded: \(msg)"
        case .remainingBytes(let count): return "Remaining \(count) unconsumed bytes"
        }
    }
}

public enum NetworkError: Error, Sendable, LocalizedError {
    case connectionFailed(String)
    case timeout(String)
    case invalidURL(String)
    case invalidResponse(String)
    case httpError(statusCode: Int, message: String)
    case retryExhausted(String)

    public var errorDescription: String? {
        switch self {
        case .connectionFailed(let msg): return "Connection failed: \(msg)"
        case .timeout(let msg): return "Timeout: \(msg)"
        case .invalidURL(let msg): return "Invalid URL: \(msg)"
        case .invalidResponse(let msg): return "Invalid response: \(msg)"
        case .httpError(let code, let msg): return "HTTP \(code): \(msg)"
        case .retryExhausted(let msg): return "Retry exhausted: \(msg)"
        }
    }
}

public enum APIError: Error, Sendable, LocalizedError {
    case aptosApiError(message: String, errorCode: String?, vmErrorCode: Int?)
    case indexerError(message: String, errors: [String])
    case faucetError(message: String)
    case decodingError(String)

    public var errorDescription: String? {
        switch self {
        case .aptosApiError(let msg, let code, let vmCode):
            var desc = msg
            if let code { desc += " (code: \(code))" }
            if let vmCode { desc += " (vm_error: \(vmCode))" }
            return desc
        case .indexerError(let msg, let errors):
            return "\(msg): \(errors.joined(separator: ", "))"
        case .faucetError(let msg): return "Faucet error: \(msg)"
        case .decodingError(let msg): return "Decoding error: \(msg)"
        }
    }
}

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
        case .buildFailed(let msg): return "Build failed: \(msg)"
        case .signFailed(let msg): return "Sign failed: \(msg)"
        case .submitFailed(let msg): return "Submit failed: \(msg)"
        case .simulationFailed(let msg): return "Simulation failed: \(msg)"
        case .waitFailed(let msg): return "Wait failed: \(msg)"
        case .executionFailed(let hash, let msg): return "Execution failed (\(hash)): \(msg)"
        case .expired(let msg): return "Transaction expired: \(msg)"
        case .invalidPayload(let msg): return "Invalid payload: \(msg)"
        case .invalidAuthenticator(let msg): return "Invalid authenticator: \(msg)"
        case .sequenceNumberMismatch(let msg): return "Sequence number mismatch: \(msg)"
        }
    }
}

public enum KeylessError: Error, Sendable, LocalizedError {
    case invalidJWT(String)
    case pepperServiceError(String)
    case proverServiceError(String)
    case proofExpired(String)
    case invalidEphemeralKeyPair(String)
    case invalidConfiguration(String)

    public var errorDescription: String? {
        switch self {
        case .invalidJWT(let msg): return "Invalid JWT: \(msg)"
        case .pepperServiceError(let msg): return "Pepper service error: \(msg)"
        case .proverServiceError(let msg): return "Prover service error: \(msg)"
        case .proofExpired(let msg): return "Proof expired: \(msg)"
        case .invalidEphemeralKeyPair(let msg): return "Invalid ephemeral key pair: \(msg)"
        case .invalidConfiguration(let msg): return "Invalid configuration: \(msg)"
        }
    }
}
