import Foundation
import P256K

// MARK: - Secp256k1PublicKey

/// Secp256k1 public key (33 bytes compressed or 65 bytes uncompressed).
public struct Secp256k1PublicKey: Sendable, Equatable, Hashable {
    /// The raw compressed public key bytes (33 bytes).
    public let data: Data

    public static let compressedLength = 33
    public static let uncompressedLength = 65

    /// Creates from raw bytes (compressed 33 bytes or uncompressed 65 bytes).
    public init(data: Data) throws {
        if data.count == Self.compressedLength {
            // Validate by parsing
            _ = try P256K.Signing.PublicKey(dataRepresentation: data, format: .compressed)
            self.data = data
        } else if data.count == Self.uncompressedLength {
            // Compress the key
            let key = try P256K.Signing.PublicKey(
                dataRepresentation: data, format: .uncompressed
            )
            self.data = Data(key.dataRepresentation)
        } else {
            throw AptosError.crypto(.invalidKeyLength(
                expected: Self.compressedLength, actual: data.count
            ))
        }
    }

    /// Creates from a hex string.
    public static func fromHex(_ hex: String) throws -> Self {
        let data = try Hex.decode(hex)
        return try Self(data: data)
    }

    /// Verifies a signature over a message hash.
    public func verify(message: Data, signature: Secp256k1Signature) -> Bool {
        guard let key = try? P256K.Signing.PublicKey(
            dataRepresentation: data, format: .compressed
        )
        else { return false }

        // Hash the message with SHA3-256 first
        let hash = SHA3.sha256(message)

        guard let ecdsaSig = try? P256K.Signing.ECDSASignature(
            dataRepresentation: signature.data
        )
        else { return false }

        return key.isValidSignature(ecdsaSig, for: hash)
    }

    /// Returns the hex representation with "0x" prefix.
    public func toHex() -> String {
        Hex.encode(data)
    }
}

// MARK: BCSSerializable, BCSDeserializable

extension Secp256k1PublicKey: BCSSerializable, BCSDeserializable {
    public func serialize(to serializer: inout Serializer) throws {
        try serializer.serializeBytes(data)
    }

    public static func deserialize(from deserializer: inout Deserializer) throws -> Secp256k1PublicKey {
        let bytes = try deserializer.deserializeBytes()
        return try Secp256k1PublicKey(data: bytes)
    }
}

// MARK: - Secp256k1PrivateKey

/// Secp256k1 private key (32 bytes).
public struct Secp256k1PrivateKey: Sendable, Equatable {
    public let data: Data

    public static let length = 32

    /// Generates a new random private key.
    public static func generate() -> Self {
        // P256K key generation is guaranteed to succeed with random entropy
        guard let key = try? P256K.Signing.PrivateKey() else {
            fatalError("Failed to generate secp256k1 key - system entropy unavailable")
        }
        return Self(unchecked: Data(key.dataRepresentation))
    }

    /// Creates from raw bytes.
    public init(data: Data) throws {
        guard data.count == Self.length else {
            throw AptosError.crypto(.invalidKeyLength(expected: Self.length, actual: data.count))
        }
        // Validate the key
        _ = try P256K.Signing.PrivateKey(dataRepresentation: data)
        self.data = data
    }

    /// Creates from a hex string.
    public static func fromHex(_ hex: String) throws -> Self {
        let data = try Hex.decode(hex)
        return try Self(data: data)
    }

    /// Creates from an AIP-80 formatted string.
    public static func fromAIP80(_ aip80: String) throws -> Self {
        let prefix = "secp256k1-priv-"
        guard aip80.hasPrefix(prefix) else {
            throw AptosError.crypto(.invalidPrivateKey("Invalid AIP-80 format for Secp256k1"))
        }
        let hex = String(aip80.dropFirst(prefix.count))
        return try fromHex(hex)
    }

    /// Returns the AIP-80 formatted string.
    public func toAIP80() -> String {
        "secp256k1-priv-\(Hex.encodeWithoutPrefix(data))"
    }

    /// Derives the compressed public key.
    public func publicKey() throws -> Secp256k1PublicKey {
        let key = try P256K.Signing.PrivateKey(dataRepresentation: data)
        return try Secp256k1PublicKey(data: Data(key.publicKey.dataRepresentation))
    }

    /// Signs a message (hashed with SHA3-256 internally, RFC 6979 deterministic, low-S normalized).
    public func sign(_ message: Data) throws -> Secp256k1Signature {
        let key = try P256K.Signing.PrivateKey(dataRepresentation: data)
        let hash = SHA3.sha256(message)
        let sig = try key.signature(for: hash)
        return try Secp256k1Signature(data: Data(sig.dataRepresentation))
    }

    private init(unchecked data: Data) {
        self.data = data
    }
}

// MARK: BCSSerializable, BCSDeserializable

extension Secp256k1PrivateKey: BCSSerializable, BCSDeserializable {
    public func serialize(to serializer: inout Serializer) throws {
        try serializer.serializeBytes(data)
    }

    public static func deserialize(from deserializer: inout Deserializer) throws -> Secp256k1PrivateKey {
        let bytes = try deserializer.deserializeBytes()
        return try Secp256k1PrivateKey(data: bytes)
    }
}

// MARK: - Secp256k1Signature

/// Secp256k1 ECDSA signature (64 bytes, compact format).
public struct Secp256k1Signature: Sendable, Equatable {
    public let data: Data

    public static let length = 64

    /// Creates from raw bytes (64-byte compact format).
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

    /// Returns the hex representation with "0x" prefix.
    public func toHex() -> String {
        Hex.encode(data)
    }
}

// MARK: BCSSerializable, BCSDeserializable

extension Secp256k1Signature: BCSSerializable, BCSDeserializable {
    public func serialize(to serializer: inout Serializer) throws {
        try serializer.serializeBytes(data)
    }

    public static func deserialize(from deserializer: inout Deserializer) throws -> Secp256k1Signature {
        let bytes = try deserializer.deserializeBytes()
        return try Secp256k1Signature(data: bytes)
    }
}
