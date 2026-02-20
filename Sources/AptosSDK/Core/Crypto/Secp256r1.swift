import Foundation
import CryptoKit

/// Secp256r1 (P-256/NIST P-256) public key for WebAuthn compatibility.
public struct Secp256r1PublicKey: Sendable, Equatable, Hashable {
    /// Raw uncompressed public key bytes (65 bytes: 0x04 + x + y).
    public let data: Data

    public static let uncompressedLength = 65
    public static let compressedLength = 33

    /// Creates from raw bytes.
    public init(data: Data) throws {
        if data.count == Self.uncompressedLength {
            _ = try P256.Signing.PublicKey(x963Representation: data)
            self.data = data
        } else if data.count == Self.compressedLength {
            let key = try P256.Signing.PublicKey(compressedRepresentation: data)
            self.data = Data(key.x963Representation)
        } else {
            throw AptosError.crypto(.invalidKeyLength(
                expected: Self.uncompressedLength, actual: data.count))
        }
    }

    /// Creates from a hex string.
    public static func fromHex(_ hex: String) throws -> Secp256r1PublicKey {
        let data = try Hex.decode(hex)
        return try Secp256r1PublicKey(data: data)
    }

    /// Verifies a signature over a message.
    public func verify(message: Data, signature: Secp256r1Signature) -> Bool {
        guard let key = try? P256.Signing.PublicKey(x963Representation: data) else {
            return false
        }
        guard let ecdsaSig = try? P256.Signing.ECDSASignature(rawRepresentation: signature.data) else {
            return false
        }
        let digest = CryptoKit.SHA256.hash(data: message)
        return key.isValidSignature(ecdsaSig, for: digest)
    }

    /// Returns the hex representation with "0x" prefix.
    public func toHex() -> String {
        Hex.encode(data)
    }
}

extension Secp256r1PublicKey: BCSSerializable, BCSDeserializable {
    public func serialize(to serializer: inout Serializer) throws {
        try serializer.serializeBytes(data)
    }

    public static func deserialize(from deserializer: inout Deserializer) throws -> Secp256r1PublicKey {
        let bytes = try deserializer.deserializeBytes()
        return try Secp256r1PublicKey(data: bytes)
    }
}

/// Secp256r1 (P-256) private key (32 bytes).
public struct Secp256r1PrivateKey: Sendable, Equatable {
    public let data: Data

    public static let length = 32

    /// Generates a new random private key.
    public static func generate() -> Secp256r1PrivateKey {
        let key = P256.Signing.PrivateKey()
        return Secp256r1PrivateKey(unchecked: Data(key.rawRepresentation))
    }

    /// Creates from raw bytes.
    public init(data: Data) throws {
        guard data.count == Self.length else {
            throw AptosError.crypto(.invalidKeyLength(expected: Self.length, actual: data.count))
        }
        _ = try P256.Signing.PrivateKey(rawRepresentation: data)
        self.data = data
    }

    /// Creates from a hex string.
    public static func fromHex(_ hex: String) throws -> Secp256r1PrivateKey {
        let data = try Hex.decode(hex)
        return try Secp256r1PrivateKey(data: data)
    }

    /// Creates from an AIP-80 formatted string.
    public static func fromAIP80(_ aip80: String) throws -> Secp256r1PrivateKey {
        let prefix = "secp256r1-priv-"
        guard aip80.hasPrefix(prefix) else {
            throw AptosError.crypto(.invalidPrivateKey("Invalid AIP-80 format for Secp256r1"))
        }
        let hex = String(aip80.dropFirst(prefix.count))
        return try fromHex(hex)
    }

    /// Returns the AIP-80 formatted string.
    public func toAIP80() -> String {
        "secp256r1-priv-\(Hex.encodeWithoutPrefix(data))"
    }

    /// Derives the public key.
    public func publicKey() throws -> Secp256r1PublicKey {
        let key = try P256.Signing.PrivateKey(rawRepresentation: data)
        return try Secp256r1PublicKey(data: Data(key.publicKey.x963Representation))
    }

    /// Signs a message.
    public func sign(_ message: Data) throws -> Secp256r1Signature {
        let key = try P256.Signing.PrivateKey(rawRepresentation: data)
        let sig = try key.signature(for: message)
        return try Secp256r1Signature(data: Data(sig.rawRepresentation))
    }

    private init(unchecked data: Data) {
        self.data = data
    }
}

extension Secp256r1PrivateKey: BCSSerializable, BCSDeserializable {
    public func serialize(to serializer: inout Serializer) throws {
        try serializer.serializeBytes(data)
    }

    public static func deserialize(from deserializer: inout Deserializer) throws -> Secp256r1PrivateKey {
        let bytes = try deserializer.deserializeBytes()
        return try Secp256r1PrivateKey(data: bytes)
    }
}

/// Secp256r1 ECDSA signature (64 bytes, raw format: r || s).
public struct Secp256r1Signature: Sendable, Equatable {
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
    public static func fromHex(_ hex: String) throws -> Secp256r1Signature {
        let data = try Hex.decode(hex)
        return try Secp256r1Signature(data: data)
    }

    /// Returns the hex representation.
    public func toHex() -> String {
        Hex.encode(data)
    }
}

extension Secp256r1Signature: BCSSerializable, BCSDeserializable {
    public func serialize(to serializer: inout Serializer) throws {
        try serializer.serializeBytes(data)
    }

    public static func deserialize(from deserializer: inout Deserializer) throws -> Secp256r1Signature {
        let bytes = try deserializer.deserializeBytes()
        return try Secp256r1Signature(data: bytes)
    }
}
