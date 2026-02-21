import CryptoKit
import CTweetNaCl
import Foundation

// MARK: - Ed25519PublicKey

/// Ed25519 public key (32 bytes).
public struct Ed25519PublicKey: Sendable, Equatable, Hashable {
    public let data: Data

    public static let length = 32

    /// Creates from raw bytes.
    public init(data: Data) throws {
        guard data.count == Self.length else {
            throw AptosError.crypto(.invalidKeyLength(expected: Self.length, actual: data.count))
        }
        // Validate by trying to create a CryptoKit key
        _ = try Curve25519.Signing.PublicKey(rawRepresentation: data)
        self.data = data
    }

    /// Creates from a hex string.
    public static func fromHex(_ hex: String) throws -> Self {
        let data = try Hex.decode(hex)
        return try Self(data: data)
    }

    /// Verifies a signature over a message.
    public func verify(message: Data, signature: Ed25519Signature) -> Bool {
        guard let key = try? Curve25519.Signing.PublicKey(rawRepresentation: data) else {
            return false
        }
        return key.isValidSignature(signature.data, for: message)
    }

    /// Returns the hex string representation with "0x" prefix.
    public func toHex() -> String {
        Hex.encode(data)
    }
}

// MARK: BCSSerializable, BCSDeserializable

extension Ed25519PublicKey: BCSSerializable, BCSDeserializable {
    public func serialize(to serializer: inout Serializer) throws {
        try serializer.serializeBytes(data)
    }

    public static func deserialize(from deserializer: inout Deserializer) throws -> Ed25519PublicKey {
        let bytes = try deserializer.deserializeBytes()
        return try Ed25519PublicKey(data: bytes)
    }
}

// MARK: - Ed25519PrivateKey

/// Ed25519 private key (32 bytes).
///
/// Conforms to `CustomStringConvertible` and `CustomDebugStringConvertible`
/// with redacted output to prevent accidental logging of key material.
public struct Ed25519PrivateKey: Sendable, Equatable, CustomStringConvertible,
    CustomDebugStringConvertible {
    public private(set) var data: Data

    public static let length = 32

    /// Generates a new random private key.
    public static func generate() -> Self {
        let key = Curve25519.Signing.PrivateKey()
        return Self(unchecked: Data(key.rawRepresentation))
    }

    /// Creates from raw bytes (32-byte seed).
    public init(data: Data) throws {
        guard data.count == Self.length || data.count == 64 else {
            throw AptosError.crypto(.invalidKeyLength(expected: Self.length, actual: data.count))
        }

        if data.count == Self.length {
            self.data = data
            return
        }

        // Extended key format: seed (32) || public_key (32)
        let seed = Data(data.prefix(32))
        let providedPublicKey = Data(data.suffix(32))

        var derivedPublicKey = [UInt8](repeating: 0, count: 32)
        var secretKey = [UInt8](repeating: 0, count: 64)
        crypto_sign_ed25519_seed_keypair(&derivedPublicKey, &secretKey, Array(seed))

        guard Data(derivedPublicKey) == providedPublicKey else {
            throw AptosError.crypto(.invalidPrivateKey(
                "Extended Ed25519 private key contains mismatched public key bytes"
            ))
        }

        // Internally store only the seed; public key is always derived.
        self.data = seed
    }

    /// Creates from a hex string.
    public static func fromHex(_ hex: String) throws -> Self {
        let data = try Hex.decode(hex)
        return try Self(data: data)
    }

    /// Creates from an AIP-80 formatted string ("ed25519-priv-<hex>").
    public static func fromAIP80(_ aip80: String) throws -> Self {
        let prefix = "ed25519-priv-"
        guard aip80.hasPrefix(prefix) else {
            throw AptosError.crypto(.invalidPrivateKey("Invalid AIP-80 format for Ed25519"))
        }
        let hex = String(aip80.dropFirst(prefix.count))
        return try fromHex(hex)
    }

    /// Returns the AIP-80 formatted string.
    public func toAIP80() -> String {
        "ed25519-priv-\(Hex.encodeWithoutPrefix(data))"
    }

    /// Derives the public key from this private key.
    ///
    /// Uses the TweetNaCl reference implementation for deterministic key derivation.
    public func publicKey() throws -> Ed25519PublicKey {
        var pk = [UInt8](repeating: 0, count: 32)
        var sk = [UInt8](repeating: 0, count: 64)
        let seed = Array(data)
        crypto_sign_ed25519_seed_keypair(&pk, &sk, seed)
        return try Ed25519PublicKey(data: Data(pk))
    }

    /// Signs a message with this private key (deterministic, RFC 8032).
    ///
    /// Uses the TweetNaCl reference implementation for deterministic Ed25519 signing.
    /// This produces the same signature bytes as other Aptos SDK implementations.
    public func sign(_ message: Data) throws -> Ed25519Signature {
        // Build the 64-byte secret key: seed || public_key
        var pk = [UInt8](repeating: 0, count: 32)
        var sk = [UInt8](repeating: 0, count: 64)
        let seed = Array(data)
        crypto_sign_ed25519_seed_keypair(&pk, &sk, seed)

        var sig = [UInt8](repeating: 0, count: 64)
        let msg = Array(message)
        crypto_sign_ed25519_detached(&sig, msg, UInt64(msg.count), sk)
        return try Ed25519Signature(data: Data(sig))
    }

    /// Overwrites the private key data with zeros.
    ///
    /// Call this when the key is no longer needed. Note that Swift value-type
    /// copies cannot be automatically zeroized — only this particular copy
    /// is cleared.
    public mutating func zeroize() {
        let count = data.count
        data = Data(repeating: 0, count: count)
    }

    public var description: String {
        "Ed25519PrivateKey(<REDACTED>)"
    }

    public var debugDescription: String {
        "Ed25519PrivateKey(<REDACTED>)"
    }

    /// Internal init that skips validation (for generate).
    private init(unchecked data: Data) {
        self.data = data
    }
}

// MARK: BCSSerializable, BCSDeserializable

extension Ed25519PrivateKey: BCSSerializable, BCSDeserializable {
    public func serialize(to serializer: inout Serializer) throws {
        try serializer.serializeBytes(data)
    }

    public static func deserialize(from deserializer: inout Deserializer) throws -> Ed25519PrivateKey {
        let bytes = try deserializer.deserializeBytes()
        return try Ed25519PrivateKey(data: bytes)
    }
}

// MARK: - Ed25519Signature

/// Ed25519 signature (64 bytes).
public struct Ed25519Signature: Sendable, Equatable {
    public let data: Data

    public static let length = 64

    /// Creates from raw bytes.
    public init(data: Data) throws {
        guard data.count == Self.length else {
            throw AptosError.crypto(.invalidSignatureLength(expected: Self.length, actual: data.count))
        }
        self.data = data
    }

    /// Creates from a hex string.
    public static func fromHex(_ hex: String) throws -> Self {
        let data = try Hex.decode(hex)
        return try Self(data: data)
    }

    /// Returns the hex string representation with "0x" prefix.
    public func toHex() -> String {
        Hex.encode(data)
    }
}

// MARK: BCSSerializable, BCSDeserializable

extension Ed25519Signature: BCSSerializable, BCSDeserializable {
    public func serialize(to serializer: inout Serializer) throws {
        try serializer.serializeBytes(data)
    }

    public static func deserialize(from deserializer: inout Deserializer) throws -> Ed25519Signature {
        let bytes = try deserializer.deserializeBytes()
        return try Ed25519Signature(data: bytes)
    }
}
