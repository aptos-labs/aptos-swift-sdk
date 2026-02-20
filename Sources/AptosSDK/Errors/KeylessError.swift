import Foundation

/// Keyless authentication error categories.
public enum KeylessErrorCategory: String, Sendable {
    case apiError = "API_ERROR"
    case externalAPIError = "EXTERNAL_API_ERROR"
    case sessionExpired = "SESSION_EXPIRED"
    case invalidState = "INVALID_STATE"
    case invalidSignature = "INVALID_SIGNATURE"
    case unknown = "UNKNOWN"
}

/// Keyless authentication error types.
public enum KeylessErrorType: String, Sendable {
    case ephemeralKeyPairExpired = "EPHEMERAL_KEY_PAIR_EXPIRED"
    case proofNotFound = "PROOF_NOT_FOUND"
    case asyncProofFetchFailed = "ASYNC_PROOF_FETCH_FAILED"
    case invalidJwtJwkNotFound = "INVALID_JWT_JWK_NOT_FOUND"
    case rateLimitExceeded = "RATE_LIMIT_EXCEEDED"
    case pepperServiceInternalError = "PEPPER_SERVICE_INTERNAL_ERROR"
    case proverServiceInternalError = "PROVER_SERVICE_INTERNAL_ERROR"
    case pepperServiceBadRequest = "PEPPER_SERVICE_BAD_REQUEST"
    case proverServiceBadRequest = "PROVER_SERVICE_BAD_REQUEST"
    case jwkFetchFailed = "JWK_FETCH_FAILED"
    case proofVerificationKeyNotFound = "PROOF_VERIFICATION_KEY_NOT_FOUND"
    case invalidJwt = "INVALID_JWT"
    case invalidEphemeralKeyPair = "INVALID_EPHEMERAL_KEY_PAIR"
    case invalidProof = "INVALID_PROOF"
    case unknown = "UNKNOWN"
}

/// Keyless authentication error.
public struct KeylessError: Error, Sendable {
    public let type: KeylessErrorType
    public let category: KeylessErrorCategory
    public let resolutionTip: String
    public let innerError: (any Error & Sendable)?
    public let details: String?

    public init(
        type: KeylessErrorType,
        category: KeylessErrorCategory,
        resolutionTip: String,
        innerError: (any Error & Sendable)? = nil,
        details: String? = nil
    ) {
        self.type = type
        self.category = category
        self.resolutionTip = resolutionTip
        self.innerError = innerError
        self.details = details
    }
}

extension KeylessError: LocalizedError {
    public var errorDescription: String? {
        var msg = "KeylessError[\(type.rawValue)]: \(resolutionTip)"
        if let details { msg += " - \(details)" }
        return msg
    }
}
