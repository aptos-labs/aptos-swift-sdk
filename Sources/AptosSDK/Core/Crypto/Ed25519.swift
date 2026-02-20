import CryptoKit
import Foundation

// MARK: - Ed25519PublicKey

/// An Ed25519 public key (32 bytes).
///
/// Conforms to `AccountPublicKey` for use in account authentication, and to
/// `Codable` for JSON serialization as a hex string.
public struct Ed25519PublicKey: AccountPublicKey, Codable {

    // MARK: - Constants

    /// The fixed byte length of an Ed25519 public key.
    public static let length = 32

    // MARK: - Storage

    /// The underlying CryptoKit representation.
    private let publicKey: Curve25519.Signing.PublicKey

    // MARK: - AccountPublicKey

    /// The raw 32-byte public key data.
    public var data: Data {
        publicKey.rawRepresentation
    }

    // MARK: - Initializers

    /// Create from raw 32-byte `Data`.
    ///
    /// - Parameter data: Exactly 32 bytes of Ed25519 public key material.
    /// - Throws: `AptosError.invalidArgument` if the length is wrong, or
    ///   `AptosError.cryptoError` if the bytes are not a valid Ed25519 point.
    public init(data: Data) throws {
        guard data.count == Self.length else {
            throw AptosError.invalidArgument(
                "Ed25519PublicKey requires exactly \(Self.length) bytes, got \(data.count)"
            )
        }
        do {
            self.publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: data)
        } catch {
            throw AptosError.cryptoError("Invalid Ed25519 public key bytes: \(error)")
        }
    }

    /// Create from a hex string (with or without `0x` prefix).
    ///
    /// - Parameter hexString: Hex-encoded 32-byte public key.
    /// - Throws: `AptosError.invalidArgument` or `AptosError.cryptoError`.
    public init(hexString: String) throws {
        let decoded = try Hex.decode(hexString)
        try self.init(data: decoded)
    }

    // MARK: - Verification

    /// Verify an Ed25519 signature over a raw message.
    ///
    /// - Parameters:
    ///   - message: The original (pre-hashed) message bytes.
    ///   - signature: An `Ed25519Signature` instance.
    /// - Returns: `true` if the signature is valid for this key and message.
    /// - Throws: `AptosError.cryptoError` if `signature` is not an `Ed25519Signature`.
    public func verify(message: Data, signature: any AccountSignature) throws -> Bool {
        guard let sig = signature as? Ed25519Signature else {
            throw AptosError.cryptoError(
                "Ed25519PublicKey.verify requires an Ed25519Signature"
            )
        }
        return publicKey.isValidSignature(sig.data, for: message)
    }

    // MARK: - Serializable

    /// BCS-serialize as length-prefixed bytes (ULEB128 length + 32 raw bytes).
    public func serialize(to serializer: inout Serializer) {
        serializer.serializeBytes(data)
    }

    // MARK: - Deserializable

    /// BCS-deserialize from a length-prefixed byte sequence.
    public static func deserialize(from deserializer: inout Deserializer) throws -> Ed25519PublicKey {
        let bytes = try deserializer.deserializeBytes()
        return try Ed25519PublicKey(data: bytes)
    }

    // MARK: - Hashable & Equatable

    public func hash(into hasher: inout Hasher) {
        hasher.combine(data)
    }

    public static func == (lhs: Ed25519PublicKey, rhs: Ed25519PublicKey) -> Bool {
        lhs.data == rhs.data
    }

    // MARK: - Codable

    /// Decode from a JSON hex string (with or without `0x` prefix).
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let hexString = try container.decode(String.self)
        try self.init(hexString: hexString)
    }

    /// Encode as a JSON hex string with `0x` prefix.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(Hex.encode(data))
    }
}

// MARK: - CustomStringConvertible

extension Ed25519PublicKey: CustomStringConvertible {
    public var description: String {
        Hex.encode(data)
    }
}

// MARK: - Ed25519PrivateKey

/// An Ed25519 private key (32 bytes).
///
/// Conforms to `AccountPrivateKey`. The raw key bytes are kept in memory only
/// as long as the value is alive; there is no additional caching.
///
/// - Important: Never log or persist the raw bytes of a private key in
///   production code.
public struct Ed25519PrivateKey: AccountPrivateKey {

    // MARK: - Associated Types

    public typealias PublicKey = Ed25519PublicKey
    public typealias Sig = Ed25519Signature

    // MARK: - Constants

    /// The fixed byte length of an Ed25519 private key (seed).
    public static let length = 32

    /// AIP-80 prefix for Ed25519 private keys.
    private static let aip80Prefix = "ed25519-priv-"

    // MARK: - Storage

    private let privateKey: Curve25519.Signing.PrivateKey

    // MARK: - AccountPrivateKey

    /// The raw 32-byte private key seed.
    public var data: Data {
        privateKey.rawRepresentation
    }

    // MARK: - Initializers

    /// Create from raw 32-byte `Data`.
    ///
    /// - Parameter data: Exactly 32 bytes of Ed25519 private key seed material.
    /// - Throws: `AptosError.invalidArgument` if the length is wrong, or
    ///   `AptosError.cryptoError` if the bytes cannot form a valid private key.
    public init(data: Data) throws {
        guard data.count == Self.length else {
            throw AptosError.invalidArgument(
                "Ed25519PrivateKey requires exactly \(Self.length) bytes, got \(data.count)"
            )
        }
        do {
            self.privateKey = try Curve25519.Signing.PrivateKey(rawRepresentation: data)
        } catch {
            throw AptosError.cryptoError("Invalid Ed25519 private key bytes: \(error)")
        }
    }

    /// Create from a hex string (with or without `0x` prefix).
    ///
    /// - Parameter hexString: Hex-encoded 32-byte private key seed.
    /// - Throws: `AptosError.invalidArgument` or `AptosError.cryptoError`.
    public init(hexString: String) throws {
        let decoded = try Hex.decode(hexString)
        try self.init(data: decoded)
    }

    /// Create from an AIP-80 formatted string (`ed25519-priv-<hex>`).
    ///
    /// AIP-80 defines a standard textual representation for private keys that
    /// includes an algorithm prefix to prevent cross-algorithm key confusion.
    ///
    /// - Parameter aip80String: A string of the form `ed25519-priv-<hex>` where
    ///   `<hex>` is the 32-byte seed encoded as lowercase hexadecimal (with or
    ///   without a `0x` prefix).
    /// - Throws: `AptosError.invalidArgument` if the prefix is missing or the
    ///   hex is malformed, or `AptosError.cryptoError` if the bytes are invalid.
    public init(aip80String: String) throws {
        guard aip80String.hasPrefix(Self.aip80Prefix) else {
            throw AptosError.invalidArgument(
                "Ed25519PrivateKey AIP-80 string must start with \"\(Self.aip80Prefix)\""
            )
        }
        let hexPart = String(aip80String.dropFirst(Self.aip80Prefix.count))
        try self.init(hexString: hexPart)
    }

    // MARK: - Generation

    /// Generate a new random Ed25519 private key using the system CSPRNG.
    ///
    /// - Returns: A freshly-generated `Ed25519PrivateKey`.
    public static func generate() -> Ed25519PrivateKey {
        // Curve25519.Signing.PrivateKey() calls SecRandomCopyBytes internally
        // on Apple platforms — no checked throws needed here.
        let key = Curve25519.Signing.PrivateKey()
        // The raw representation is always exactly 32 bytes for CryptoKit keys.
        // Force-try is safe because we know the length invariant holds.
        // swiftlint:disable:next force_try
        return try! Ed25519PrivateKey(data: key.rawRepresentation)
    }

    // MARK: - AccountPrivateKey

    /// Derive the corresponding `Ed25519PublicKey`.
    public func publicKey() -> Ed25519PublicKey {
        // CryptoKit guarantees this is always a valid 32-byte public key.
        // swiftlint:disable:next force_try
        return try! Ed25519PublicKey(data: privateKey.publicKey.rawRepresentation)
    }

    /// Sign a raw message with this key.
    ///
    /// - Parameter message: The raw message bytes to sign.
    /// - Returns: An `Ed25519Signature` over `message`.
    /// - Throws: `AptosError.cryptoError` if signing fails.
    public func sign(message: Data) throws -> Ed25519Signature {
        let signatureData: Data
        do {
            signatureData = try privateKey.signature(for: message)
        } catch {
            throw AptosError.cryptoError("Ed25519 signing failed: \(error)")
        }
        // CryptoKit always produces a 64-byte signature; the force-try is safe.
        // swiftlint:disable:next force_try
        return try! Ed25519Signature(data: signatureData)
    }

    // MARK: - AIP-80 Export

    /// Encode this private key as an AIP-80 formatted string.
    ///
    /// - Returns: A string of the form `ed25519-priv-0x<hex>`.
    public func toAIP80String() -> String {
        "\(Self.aip80Prefix)\(Hex.encode(data))"
    }
}

// MARK: - Ed25519Signature

/// An Ed25519 signature (64 bytes).
///
/// Conforms to `AccountSignature` for use in transaction authenticators.
public struct Ed25519Signature: AccountSignature {

    // MARK: - Constants

    /// The fixed byte length of an Ed25519 signature.
    public static let length = 64

    // MARK: - Storage

    /// The raw 64-byte signature.
    public let data: Data

    // MARK: - Initializers

    /// Create from raw 64-byte `Data`.
    ///
    /// - Parameter data: Exactly 64 bytes of Ed25519 signature material.
    /// - Throws: `AptosError.invalidArgument` if the length is wrong.
    public init(data: Data) throws {
        guard data.count == Self.length else {
            throw AptosError.invalidArgument(
                "Ed25519Signature requires exactly \(Self.length) bytes, got \(data.count)"
            )
        }
        self.data = data
    }

    /// Create from a hex string (with or without `0x` prefix).
    ///
    /// - Parameter hexString: Hex-encoded 64-byte signature.
    /// - Throws: `AptosError.invalidArgument` if the length or encoding is wrong.
    public init(hexString: String) throws {
        let decoded = try Hex.decode(hexString)
        try self.init(data: decoded)
    }

    // MARK: - Serializable

    /// BCS-serialize as length-prefixed bytes (ULEB128 length + 64 raw bytes).
    public func serialize(to serializer: inout Serializer) {
        serializer.serializeBytes(data)
    }

    // MARK: - Deserializable

    /// BCS-deserialize from a length-prefixed byte sequence.
    public static func deserialize(from deserializer: inout Deserializer) throws -> Ed25519Signature {
        let bytes = try deserializer.deserializeBytes()
        return try Ed25519Signature(data: bytes)
    }

    // MARK: - Hashable & Equatable

    public func hash(into hasher: inout Hasher) {
        hasher.combine(data)
    }

    public static func == (lhs: Ed25519Signature, rhs: Ed25519Signature) -> Bool {
        lhs.data == rhs.data
    }
}

// MARK: - CustomStringConvertible

extension Ed25519Signature: CustomStringConvertible {
    public var description: String {
        Hex.encode(data)
    }
}
