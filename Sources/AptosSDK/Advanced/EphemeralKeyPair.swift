import CryptoKit
import Foundation
import Security

// MARK: - EphemeralKeyPair

/// An ephemeral key pair used for keyless authentication.
///
/// Ephemeral key pairs are short-lived Ed25519 keys with an expiry date.
/// They are used in the keyless flow to sign transactions on behalf of
/// a user authenticated via OIDC (e.g., Google, Apple Sign-In).
public struct EphemeralKeyPair: Sendable {
    /// The ephemeral private key.
    public let privateKey: Ed25519PrivateKey

    /// The ephemeral public key.
    public let publicKey: Ed25519PublicKey

    /// The expiry date of this key pair (Unix timestamp in seconds).
    public let expiryDateSecs: UInt64

    /// The nonce used in the OIDC flow.
    public let nonce: String

    /// The blinding factor used in nonce computation (31 bytes when present).
    public let blindingFactor: Data?

    /// Maximum lifespan: 24 hours.
    public static let maxExpiryHours: UInt64 = 24

    /// Length of the blinding factor in bytes.
    public static let blindingFactorLength = 31

    /// Creates a new ephemeral key pair with the given expiry.
    ///
    /// - Parameter expiryDateSecs: Unix timestamp when this key expires.
    ///   Must be within 24 hours from now.
    public init(expiryDateSecs: UInt64? = nil) throws {
        let now = UInt64(Date().timeIntervalSince1970)
        let defaultExpiry = now + Self.maxExpiryHours * 3600
        let expiry = expiryDateSecs ?? defaultExpiry

        guard expiry > now else {
            throw AptosError.keyless(.invalidConfiguration("Expiry must be in the future"))
        }

        guard expiry <= now + Self.maxExpiryHours * 3600 else {
            throw AptosError.keyless(.invalidConfiguration(
                "Expiry cannot be more than \(Self.maxExpiryHours) hours in the future"
            ))
        }

        privateKey = Ed25519PrivateKey.generate()
        publicKey = try privateKey.publicKey()
        self.expiryDateSecs = expiry

        // Generate random 31-byte blinding factor
        var bytes = [UInt8](repeating: 0, count: Self.blindingFactorLength)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else {
            throw AptosError.crypto(.signatureFailed("Failed to generate random blinding factor"))
        }
        blindingFactor = Data(bytes)

        nonce = Self.computeNonce(
            publicKey: publicKey, expiryDateSecs: expiry, blindingFactor: blindingFactor
        )
    }

    /// Creates from an existing private key (for deserialization/reconstruction).
    public init(
        privateKey: Ed25519PrivateKey,
        expiryDateSecs: UInt64,
        blindingFactor: Data? = nil
    ) throws {
        self.privateKey = privateKey
        publicKey = try privateKey.publicKey()
        self.expiryDateSecs = expiryDateSecs
        self.blindingFactor = blindingFactor
        nonce = Self.computeNonce(
            publicKey: publicKey, expiryDateSecs: expiryDateSecs, blindingFactor: blindingFactor
        )
    }

    /// Whether this key pair has expired.
    public var isExpired: Bool {
        UInt64(Date().timeIntervalSince1970) >= expiryDateSecs
    }

    /// Signs a message using the ephemeral private key.
    public func sign(_ message: Data) throws -> Ed25519Signature {
        guard !isExpired else {
            throw AptosError.keyless(.invalidConfiguration("Ephemeral key pair has expired"))
        }
        return try privateKey.sign(message)
    }

    /// Computes the nonce from the public key, expiry, and optional blinding factor.
    ///
    /// nonce = SHA3-256(publicKeyBytes || expiryDateSecs as LE u64 || blindingFactor?)
    /// truncated to first 32 hex chars
    private static func computeNonce(
        publicKey: Ed25519PublicKey,
        expiryDateSecs: UInt64,
        blindingFactor: Data?
    ) -> String {
        var data = publicKey.data
        var expiry = expiryDateSecs.littleEndian
        data.append(Data(bytes: &expiry, count: 8))
        if let blindingFactor {
            data.append(blindingFactor)
        }
        let hash = SHA3.sha256(Array(data))
        return Hex.encodeWithoutPrefix(Data(hash.prefix(16)))
    }
}

// MARK: BCSSerializable, BCSDeserializable

extension EphemeralKeyPair: BCSSerializable, BCSDeserializable {
    public func serialize(to serializer: inout Serializer) throws {
        try privateKey.serialize(to: &serializer)
        serializer.serializeU64(expiryDateSecs)
        if let blindingFactor {
            serializer.serializeBool(true)
            serializer.serializeFixedBytes(blindingFactor)
        } else {
            serializer.serializeBool(false)
        }
    }

    public static func deserialize(from deserializer: inout Deserializer) throws -> EphemeralKeyPair {
        let privKey = try Ed25519PrivateKey.deserialize(from: &deserializer)
        let expiry = try deserializer.deserializeU64()
        let hasBlinding = try deserializer.deserializeBool()
        let blinding: Data? = if hasBlinding {
            try deserializer.deserializeFixedBytes(count: EphemeralKeyPair.blindingFactorLength)
        } else {
            nil
        }
        return try EphemeralKeyPair(
            privateKey: privKey, expiryDateSecs: expiry, blindingFactor: blinding
        )
    }
}
