import Foundation
import P256K

// MARK: - Constants

private let secp256k1UncompressedPublicKeyLength = 65
private let secp256k1CompressedPublicKeyLength = 33
private let secp256k1PrivateKeyLength = 32
private let secp256k1SignatureLength = 64
private let secp256k1AIP80Prefix = "secp256k1-priv-"

// MARK: - Secp256k1PublicKey

/// A secp256k1 ECDSA public key.
///
/// Supports both uncompressed (65-byte, `04 || X || Y`) and compressed
/// (33-byte, `02/03 || X`) representations. The stored form is always
/// the uncompressed 65-byte form, matching the Aptos protocol.
public struct Secp256k1PublicKey: AccountPublicKey {
    /// The canonical uncompressed 65-byte public key.
    public let data: Data

    /// Create from raw bytes (65-byte uncompressed or 33-byte compressed).
    public init(_ bytes: Data) throws {
        switch bytes.count {
        case secp256k1UncompressedPublicKeyLength:
            guard bytes[bytes.startIndex] == 0x04 else {
                throw AptosError.cryptoError(
                    "Secp256k1 uncompressed public key must begin with 0x04"
                )
            }
            self.data = bytes

        case secp256k1CompressedPublicKeyLength:
            let prefix = bytes[bytes.startIndex]
            guard prefix == 0x02 || prefix == 0x03 else {
                throw AptosError.cryptoError(
                    "Secp256k1 compressed public key must begin with 0x02 or 0x03"
                )
            }
            // Decompress using secp256k1.swift
            let key = try P256K.Signing.PublicKey(
                dataRepresentation: bytes,
                format: .compressed
            )
            self.data = Data(key.uncompressedRepresentation)

        default:
            throw AptosError.cryptoError(
                "Secp256k1 public key must be \(secp256k1UncompressedPublicKeyLength) or "
                    + "\(secp256k1CompressedPublicKeyLength) bytes, got \(bytes.count)"
            )
        }
    }

    /// Create from a hex string.
    public init(hexString: String) throws {
        try self.init(try Hex.decode(hexString))
    }

    // MARK: - Verification

    public func verify(message: Data, signature: any AccountSignature) throws -> Bool {
        guard let sig = signature as? Secp256k1Signature else {
            throw AptosError.cryptoError(
                "Secp256k1PublicKey.verify requires a Secp256k1Signature"
            )
        }
        let pubKey = try P256K.Signing.PublicKey(
            dataRepresentation: data,
            format: .uncompressed
        )
        let ecdsaSig = try P256K.Signing.ECDSASignature(
            dataRepresentation: sig.data
        )
        // P256K's isValidSignature(for:) internally hashes with SHA256
        return pubKey.isValidSignature(ecdsaSig, for: message)
    }

    // MARK: - Serializable / Deserializable

    public func serialize(to serializer: inout Serializer) {
        serializer.serializeBytes(data)
    }

    public static func deserialize(from deserializer: inout Deserializer) throws -> Secp256k1PublicKey {
        let bytes = try deserializer.deserializeBytes()
        return try Secp256k1PublicKey(bytes)
    }

    // MARK: - Equatable / Hashable

    public static func == (lhs: Secp256k1PublicKey, rhs: Secp256k1PublicKey) -> Bool {
        lhs.data == rhs.data
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(data)
    }
}

extension Secp256k1PublicKey: CustomStringConvertible {
    public var description: String { Hex.encode(data) }
}

// MARK: - Secp256k1PrivateKey

/// A secp256k1 ECDSA private key (32 bytes).
public struct Secp256k1PrivateKey: @unchecked Sendable, AccountPrivateKey {
    public typealias PublicKey = Secp256k1PublicKey
    public typealias Sig = Secp256k1Signature

    public let data: Data
    private let _key: P256K.Signing.PrivateKey

    /// Create from raw 32-byte data.
    public init(_ bytes: Data) throws {
        guard bytes.count == secp256k1PrivateKeyLength else {
            throw AptosError.cryptoError(
                "Secp256k1 private key must be \(secp256k1PrivateKeyLength) bytes, got \(bytes.count)"
            )
        }
        self._key = try P256K.Signing.PrivateKey(dataRepresentation: bytes)
        self.data = bytes
    }

    /// Create from a hex string.
    public init(hexString: String) throws {
        try self.init(try Hex.decode(hexString))
    }

    /// Create from an AIP-80 formatted string.
    public init(aip80 aip80String: String) throws {
        guard aip80String.hasPrefix(secp256k1AIP80Prefix) else {
            throw AptosError.invalidArgument(
                "Secp256k1 AIP-80 private key must begin with \"\(secp256k1AIP80Prefix)\""
            )
        }
        let hexPart = String(aip80String.dropFirst(secp256k1AIP80Prefix.count))
        try self.init(try Hex.decode(hexPart))
    }

    /// Generate a new random key.
    public static func generate() -> Secp256k1PrivateKey {
        let key = try! P256K.Signing.PrivateKey()
        return try! Secp256k1PrivateKey(Data(key.dataRepresentation))
    }

    public func publicKey() -> Secp256k1PublicKey {
        try! Secp256k1PublicKey(Data(_key.publicKey.uncompressedRepresentation))
    }

    public func sign(message: Data) throws -> Secp256k1Signature {
        // P256K's signature(for:) internally hashes with SHA256
        let ecdsaSig = try _key.signature(for: message)
        return try Secp256k1Signature(Data(ecdsaSig.dataRepresentation))
    }

    /// Return the key in AIP-80 format.
    public func toAIP80String() -> String {
        secp256k1AIP80Prefix + Hex.encode(data)
    }
}

extension Secp256k1PrivateKey: CustomStringConvertible {
    public var description: String { "<Secp256k1PrivateKey redacted>" }
}


// MARK: - Secp256k1Signature

/// A secp256k1 ECDSA signature (64 bytes, r||s format).
public struct Secp256k1Signature: AccountSignature {
    public let data: Data

    public init(_ bytes: Data) throws {
        guard bytes.count == secp256k1SignatureLength else {
            throw AptosError.cryptoError(
                "Secp256k1 signature must be \(secp256k1SignatureLength) bytes, got \(bytes.count)"
            )
        }
        self.data = bytes
    }

    public init(hexString: String) throws {
        try self.init(try Hex.decode(hexString))
    }

    public func serialize(to serializer: inout Serializer) {
        serializer.serializeBytes(data)
    }

    public static func deserialize(from deserializer: inout Deserializer) throws -> Secp256k1Signature {
        let bytes = try deserializer.deserializeBytes()
        return try Secp256k1Signature(bytes)
    }

    public static func == (lhs: Secp256k1Signature, rhs: Secp256k1Signature) -> Bool {
        lhs.data == rhs.data
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(data)
    }
}

extension Secp256k1Signature: CustomStringConvertible {
    public var description: String { Hex.encode(data) }
}
