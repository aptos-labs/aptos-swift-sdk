import Foundation

/// Base SDK error type.
public enum AptosError: Error, Sendable {
    case configurationError(String)
    case serializationError(String)
    case deserializationError(String)
    case cryptoError(String)
    case invalidArgument(String)
    case networkError(String)
    case internalError(String)
}

extension AptosError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .configurationError(let msg): return "Configuration error: \(msg)"
        case .serializationError(let msg): return "Serialization error: \(msg)"
        case .deserializationError(let msg): return "Deserialization error: \(msg)"
        case .cryptoError(let msg): return "Crypto error: \(msg)"
        case .invalidArgument(let msg): return "Invalid argument: \(msg)"
        case .networkError(let msg): return "Network error: \(msg)"
        case .internalError(let msg): return "Internal error: \(msg)"
        }
    }
}
