import Foundation

/// An authentication key derived from a public key.
///
/// The authentication key is computed as `SHA3-256(publicKeyBytes || signingScheme)`.
/// For new accounts, the account address is derived directly from the authentication key.
public struct AuthenticationKey: Sendable, Equatable, Hashable {
    public let data: Data

    public static let length = 32

    /// Creates from raw bytes.
    public init(data: Data) throws {
        guard data.count == Self.length else {
            throw AptosError.crypto(.invalidKeyLength(expected: Self.length, actual: data.count))
        }
        self.data = data
    }

    /// Derives an authentication key from an Ed25519 public key using the legacy scheme.
    public static func fromEd25519(publicKey: Ed25519PublicKey) -> AuthenticationKey {
        var bytes = Data(publicKey.data)
        bytes.append(SigningScheme.ed25519.rawValue)
        let hash = SHA3.sha256(bytes)
        return try! AuthenticationKey(data: hash)
    }

    /// Derives an authentication key from a single key (AnyPublicKey).
    public static func fromSingleKey(publicKey: AnyPublicKey) throws -> AuthenticationKey {
        var encoded = try bcsToBytes(publicKey)
        encoded.append(SigningScheme.singleKey.rawValue)
        let hash = SHA3.sha256(encoded)
        return try AuthenticationKey(data: hash)
    }

    /// Derives an authentication key from a MultiKey.
    public static func fromMultiKey(multiKey: MultiKey) throws -> AuthenticationKey {
        var encoded = try bcsToBytes(multiKey)
        encoded.append(SigningScheme.multiKey.rawValue)
        let hash = SHA3.sha256(encoded)
        return try AuthenticationKey(data: hash)
    }

    /// Derives an authentication key from a MultiEd25519 public key.
    public static func fromMultiEd25519(publicKey: MultiEd25519PublicKey) throws -> AuthenticationKey {
        var encoded = try bcsToBytes(publicKey)
        encoded.append(SigningScheme.multiEd25519.rawValue)
        let hash = SHA3.sha256(encoded)
        return try AuthenticationKey(data: hash)
    }

    /// Derives the account address from this authentication key.
    public func accountAddress() -> AccountAddress {
        AccountAddress(bytes: data)!
    }

    /// Returns the hex string representation.
    public func toHex() -> String {
        Hex.encode(data)
    }
}

// MARK: - Signing Schemes

/// The signing schemes supported by the Aptos blockchain.
public enum SigningScheme: UInt8, Sendable {
    case ed25519 = 0
    case multiEd25519 = 1
    case singleKey = 2
    case multiKey = 3
}

/// Input enum for specifying which key scheme to use when generating accounts.
public enum SigningSchemeInput: Sendable {
    case ed25519
    case secp256k1Ecdsa
    case secp256r1Ecdsa
}
