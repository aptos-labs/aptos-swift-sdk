import CryptoKit
import Foundation

// MARK: - Protocols

/// A public key that can verify signatures.
public protocol AccountPublicKey: Serializable, Deserializable, Sendable, Hashable {
    /// The raw bytes of the public key.
    var data: Data { get }

    /// Verify a signature over a raw message.
    func verify(message: Data, signature: any AccountSignature) throws -> Bool
}

/// A private key that can sign messages.
public protocol AccountPrivateKey: Sendable {
    associatedtype PublicKey: AccountPublicKey
    associatedtype Signature: AccountSignature

    /// The raw bytes of the private key.
    var data: Data { get }

    /// Derive the corresponding public key.
    func publicKey() -> PublicKey

    /// Sign a raw message, returning the signature.
    func sign(message: Data) throws -> Signature
}

/// A cryptographic signature.
public protocol AccountSignature: Serializable, Deserializable, Sendable, Hashable {
    /// The raw bytes of the signature.
    var data: Data { get }
}

// MARK: - Constants

private let secp256r1UncompressedPublicKeyLength = 65
private let secp256r1CompressedPublicKeyLength = 33
private let secp256r1PrivateKeyLength = 32
private let secp256r1SignatureLength = 64

/// The AIP-80 prefix for secp256r1 private keys.
private let secp256r1AIP80Prefix = "secp256r1-priv-"

// MARK: - Secp256r1PublicKey

/// A secp256r1 (NIST P-256) ECDSA public key.
///
/// Supports both uncompressed (65-byte, `04 || X || Y`) and compressed
/// (33-byte, `02/03 || X`) representations. The canonical stored form is
/// always the uncompressed 65-byte form, matching the Aptos protocol.
public struct Secp256r1PublicKey: AccountPublicKey {

    // MARK: Stored State

    /// The canonical uncompressed 65-byte public key (`04 || X || Y`).
    public let data: Data

    // MARK: Init

    /// Create from raw bytes.
    ///
    /// Accepts either:
    /// - 65-byte uncompressed (`04 || X || Y`)
    /// - 33-byte compressed (`02/03 || X`)
    ///
    /// - Parameter bytes: The raw public key bytes.
    /// - Throws: ``AptosError/cryptoError(_:)`` if the length or prefix is invalid.
    public init(_ bytes: Data) throws {
        switch bytes.count {
        case secp256r1UncompressedPublicKeyLength:
            guard bytes[bytes.startIndex] == 0x04 else {
                throw AptosError.cryptoError(
                    "Secp256r1 uncompressed public key must begin with 0x04"
                )
            }
            // Validate that CryptoKit can parse it.
            _ = try Self.parseCryptoKitKey(from: bytes)
            self.data = bytes

        case secp256r1CompressedPublicKeyLength:
            let prefix = bytes[bytes.startIndex]
            guard prefix == 0x02 || prefix == 0x03 else {
                throw AptosError.cryptoError(
                    "Secp256r1 compressed public key must begin with 0x02 or 0x03"
                )
            }
            // Decompress: reconstruct a CryptoKit key and export uncompressed.
            let key = try Self.parseCryptoKitKey(from: bytes)
            self.data = key.x963Representation   // 65 bytes: 04 || X || Y

        default:
            throw AptosError.cryptoError(
                "Secp256r1 public key must be \(secp256r1UncompressedPublicKeyLength) bytes "
                + "(uncompressed) or \(secp256r1CompressedPublicKeyLength) bytes (compressed), "
                + "got \(bytes.count)"
            )
        }
    }

    /// Return the underlying `P256.Signing.PublicKey` value.
    public func cryptoKitKey() throws -> P256.Signing.PublicKey {
        try Self.parseCryptoKitKey(from: data)
    }

    // MARK: AccountPublicKey

    /// Verify a ``Secp256r1Signature`` over a pre-hashed or raw message.
    ///
    /// The message bytes are verified directly (the caller is responsible for
    /// any domain-separation hashing). The signature must be a
    /// ``Secp256r1Signature`` (raw 64-byte r||s); other types throw.
    ///
    /// - Parameters:
    ///   - message: The raw message bytes to verify.
    ///   - signature: A ``Secp256r1Signature`` produced by the matching private key.
    /// - Returns: `true` if the signature is valid.
    /// - Throws: ``AptosError/cryptoError(_:)`` if the signature type is wrong or verification fails.
    public func verify(message: Data, signature: any AccountSignature) throws -> Bool {
        guard let sig = signature as? Secp256r1Signature else {
            throw AptosError.cryptoError(
                "Secp256r1PublicKey.verify requires a Secp256r1Signature"
            )
        }
        let pubKey = try cryptoKitKey()
        let ecdsaSig = try P256.Signing.ECDSASignature(rawRepresentation: sig.data)
        return pubKey.isValidSignature(ecdsaSig, for: message)
    }

    // MARK: Serializable / Deserializable

    /// BCS-serialize as length-prefixed bytes (uncompressed 65-byte form).
    public func serialize(to serializer: inout Serializer) {
        serializer.serializeBytes(data)
    }

    /// BCS-deserialize from length-prefixed bytes.
    public static func deserialize(from deserializer: inout Deserializer) throws -> Self {
        let bytes = try deserializer.deserializeBytes()
        return try Self(bytes)
    }

    // MARK: Equatable / Hashable

    public static func == (lhs: Secp256r1PublicKey, rhs: Secp256r1PublicKey) -> Bool {
        lhs.data == rhs.data
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(data)
    }

    // MARK: Private Helpers

    /// Parse a `P256.Signing.PublicKey` from either compressed or uncompressed bytes.
    private static func parseCryptoKitKey(from bytes: Data) throws -> P256.Signing.PublicKey {
        // CryptoKit's `x963Representation` init accepts both compressed (33-byte)
        // and uncompressed (65-byte) ANSI X9.63 representations.
        do {
            return try P256.Signing.PublicKey(x963Representation: bytes)
        } catch {
            throw AptosError.cryptoError(
                "Invalid secp256r1 public key bytes: \(error.localizedDescription)"
            )
        }
    }
}

// MARK: - CustomStringConvertible

extension Secp256r1PublicKey: CustomStringConvertible {
    public var description: String {
        Hex.encode(data)
    }
}

// MARK: - Secp256r1PrivateKey

/// A secp256r1 (NIST P-256) ECDSA private key.
///
/// Internally backed by a `P256.Signing.PrivateKey`. The canonical public key
/// representation is always the uncompressed 65-byte (`04 || X || Y`) form.
public struct Secp256r1PrivateKey: AccountPrivateKey {

    // MARK: Stored State

    /// The raw 32-byte private key scalar.
    public let data: Data

    /// The underlying CryptoKit private key.
    private let _key: P256.Signing.PrivateKey

    // MARK: Init (raw bytes)

    /// Create from raw 32-byte private key scalar data.
    ///
    /// - Parameter bytes: Exactly 32 bytes representing the private key scalar.
    /// - Throws: ``AptosError/cryptoError(_:)`` if length is wrong or bytes are invalid.
    public init(_ bytes: Data) throws {
        guard bytes.count == secp256r1PrivateKeyLength else {
            throw AptosError.cryptoError(
                "Secp256r1 private key must be \(secp256r1PrivateKeyLength) bytes, got \(bytes.count)"
            )
        }
        do {
            self._key = try P256.Signing.PrivateKey(rawRepresentation: bytes)
        } catch {
            throw AptosError.cryptoError(
                "Invalid secp256r1 private key bytes: \(error.localizedDescription)"
            )
        }
        self.data = bytes
    }

    // MARK: Init (AIP-80 string)

    /// Create from an AIP-80 formatted private key string.
    ///
    /// The expected format is `secp256r1-priv-<hex>`, where `<hex>` is the
    /// 32-byte private key scalar encoded as a lowercase hex string
    /// (with or without a `0x` prefix).
    ///
    /// - Parameter aip80String: An AIP-80 formatted private key string.
    /// - Throws: ``AptosError/invalidArgument(_:)`` if the format is wrong,
    ///           or ``AptosError/cryptoError(_:)`` if the key bytes are invalid.
    public init(aip80 aip80String: String) throws {
        guard aip80String.hasPrefix(secp256r1AIP80Prefix) else {
            throw AptosError.invalidArgument(
                "Secp256r1 AIP-80 private key must begin with \"\(secp256r1AIP80Prefix)\", "
                + "got: \"\(aip80String)\""
            )
        }
        let hexPart = String(aip80String.dropFirst(secp256r1AIP80Prefix.count))
        let bytes = try Hex.decode(hexPart)
        try self.init(bytes)
    }

    // MARK: Generate

    /// Generate a new random secp256r1 private key.
    ///
    /// - Returns: A freshly generated ``Secp256r1PrivateKey``.
    public static func generate() -> Secp256r1PrivateKey {
        let key = P256.Signing.PrivateKey()
        // P256.Signing.PrivateKey.rawRepresentation is always 32 bytes.
        // Force-try is safe: CryptoKit guarantees the raw representation is valid.
        // swiftlint:disable:next force_try
        return try! Secp256r1PrivateKey(key.rawRepresentation)
    }

    // MARK: AIP-80

    /// Return the key in AIP-80 format (`secp256r1-priv-<hex>`).
    public func toAIP80String() -> String {
        secp256r1AIP80Prefix + data.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: AccountPrivateKey

    /// Derive the corresponding ``Secp256r1PublicKey`` in uncompressed form.
    public func publicKey() -> Secp256r1PublicKey {
        // _key.publicKey.x963Representation is always the 65-byte uncompressed form.
        // Force-try is safe: the public key bytes we store are always valid.
        // swiftlint:disable:next force_try
        return try! Secp256r1PublicKey(_key.publicKey.x963Representation)
    }

    /// Sign a message, returning a raw 64-byte ``Secp256r1Signature`` (r||s).
    ///
    /// CryptoKit produces DER-encoded ECDSA signatures; this method converts
    /// them to the compact raw (r||s) format required by the Aptos protocol.
    ///
    /// - Parameter message: The raw message bytes to sign.
    /// - Returns: A ``Secp256r1Signature`` with the raw 64-byte r||s encoding.
    /// - Throws: ``AptosError/cryptoError(_:)`` if signing fails.
    public func sign(message: Data) throws -> Secp256r1Signature {
        let derSig: P256.Signing.ECDSASignature
        do {
            derSig = try _key.signature(for: message)
        } catch {
            throw AptosError.cryptoError(
                "Secp256r1 signing failed: \(error.localizedDescription)"
            )
        }
        // Convert from DER to raw 64-byte r||s.
        let rawBytes = derSig.rawRepresentation   // CryptoKit: always 64-byte r||s
        return try Secp256r1Signature(rawBytes)
    }
}

// MARK: - CustomStringConvertible

extension Secp256r1PrivateKey: CustomStringConvertible {
    public var description: String {
        "<Secp256r1PrivateKey redacted>"
    }
}

// MARK: - Secp256r1Signature

/// A secp256r1 (NIST P-256) ECDSA signature.
///
/// Stored in compact raw form: exactly 64 bytes, encoding `r || s`
/// as two 32-byte big-endian unsigned integers. This is the format
/// required by the Aptos protocol; it is **not** DER-encoded.
public struct Secp256r1Signature: AccountSignature {

    // MARK: Stored State

    /// The raw 64-byte signature (r||s).
    public let data: Data

    // MARK: Init

    /// Create from raw 64-byte r||s signature bytes.
    ///
    /// - Parameter bytes: Exactly 64 bytes in r||s format.
    /// - Throws: ``AptosError/cryptoError(_:)`` if the length is wrong.
    public init(_ bytes: Data) throws {
        guard bytes.count == secp256r1SignatureLength else {
            throw AptosError.cryptoError(
                "Secp256r1 signature must be \(secp256r1SignatureLength) bytes, got \(bytes.count)"
            )
        }
        self.data = bytes
    }

    // MARK: AccountSignature

    /// BCS-serialize as length-prefixed bytes.
    public func serialize(to serializer: inout Serializer) {
        serializer.serializeBytes(data)
    }

    /// BCS-deserialize from length-prefixed bytes.
    public static func deserialize(from deserializer: inout Deserializer) throws -> Self {
        let bytes = try deserializer.deserializeBytes()
        return try Self(bytes)
    }

    // MARK: Equatable / Hashable

    public static func == (lhs: Secp256r1Signature, rhs: Secp256r1Signature) -> Bool {
        lhs.data == rhs.data
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(data)
    }
}

// MARK: - CustomStringConvertible

extension Secp256r1Signature: CustomStringConvertible {
    public var description: String {
        Hex.encode(data)
    }
}
