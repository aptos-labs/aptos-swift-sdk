import Foundation

// MARK: - AuthenticationKey

/// An authentication key derived from a public key.
///
/// Most authentication keys are computed as `SHA3-256(publicKeyBytes || signingScheme)`.
/// Keyless accounts use a dedicated derivation formula (see `fromKeyless`).
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
    public static func fromEd25519(publicKey: Ed25519PublicKey) -> Self {
        var bytes = Data(publicKey.data)
        bytes.append(SigningScheme.ed25519.rawValue)
        return Self(unchecked: SHA3.sha256(bytes))
    }

    /// Derives an authentication key from a single key (AnyPublicKey).
    public static func fromSingleKey(publicKey: AnyPublicKey) throws -> Self {
        if case .keyless = publicKey {
            throw AptosError.crypto(.unsupportedScheme(
                "Keyless authentication keys must be derived via fromKeyless(...)"
            ))
        }
        var encoded = try bcsToBytes(publicKey)
        encoded.append(SigningScheme.singleKey.rawValue)
        let hash = SHA3.sha256(encoded)
        return try Self(data: hash)
    }

    /// Derives an authentication key from a MultiKey.
    public static func fromMultiKey(multiKey: MultiKey) throws -> Self {
        var encoded = try bcsToBytes(multiKey)
        encoded.append(SigningScheme.multiKey.rawValue)
        let hash = SHA3.sha256(encoded)
        return try Self(data: hash)
    }

    /// Derives an authentication key from a MultiEd25519 public key.
    public static func fromMultiEd25519(publicKey: MultiEd25519PublicKey) throws -> Self {
        var encoded = try bcsToBytes(publicKey)
        encoded.append(SigningScheme.multiEd25519.rawValue)
        let hash = SHA3.sha256(encoded)
        return try Self(data: hash)
    }

    /// Derives an authentication key for keyless accounts.
    ///
    /// Formula:
    /// SHA3-256(
    ///   SHA3-256(issuer) ||
    ///   SHA3-256(audience) ||
    ///   SHA3-256(uidKey || uidVal) ||
    ///   pepper (31 bytes) ||
    ///   0x05
    /// )
    public static func fromKeyless(
        issuer: String,
        audience: String,
        uidKey: String,
        uidVal: String,
        pepper: Data
    ) throws -> Self {
        guard pepper.count == 31 else {
            throw AptosError.keyless(.invalidConfiguration(
                "Keyless pepper must be exactly 31 bytes, got \(pepper.count)"
            ))
        }
        var data = Data()
        data.append(SHA3.sha256(Data(issuer.utf8)))
        data.append(SHA3.sha256(Data(audience.utf8)))

        var uidInput = Data(uidKey.utf8)
        uidInput.append(Data(uidVal.utf8))
        data.append(SHA3.sha256(uidInput))

        data.append(pepper)
        data.append(SigningScheme.keyless.rawValue)
        return try Self(data: SHA3.sha256(data))
    }

    /// Derives the account address from this authentication key.
    public func accountAddress() -> AccountAddress {
        guard let address = AccountAddress(bytes: data) else {
            preconditionFailure(
                "AuthenticationKey data must produce a valid AccountAddress; got invalid bytes."
            )
        }
        return address
    }

    /// Returns the hex string representation.
    public func toHex() -> String {
        Hex.encode(data)
    }

    private init(unchecked data: Data) {
        self.data = data
    }
}

// MARK: - SigningScheme

/// The signing schemes supported by the Aptos blockchain.
public enum SigningScheme: UInt8, Sendable {
    case ed25519 = 0
    case multiEd25519 = 1
    case singleKey = 2
    case multiKey = 3
    case keyless = 5
}

// MARK: - SigningSchemeInput

/// Input enum for specifying which key scheme to use when generating accounts.
public enum SigningSchemeInput: Sendable {
    case ed25519
    case secp256k1Ecdsa
    case secp256r1Ecdsa
}
