import Foundation

// MARK: - SigningScheme

/// The on-chain signing scheme used to authenticate an account.
///
/// These values are serialised as their raw integer variant index (a single byte) when
/// computing authentication keys and when encoding authenticators.
public enum SigningScheme: UInt8, Sendable, Hashable, Equatable {
    /// Legacy Ed25519 single-key scheme (variant 0).
    case ed25519 = 0
    /// Legacy M-of-N Ed25519 multi-key scheme (variant 1).
    case multiEd25519 = 1
    /// Single-key scheme using `AnyPublicKey` wrapper (variant 2).
    case singleKey = 2
    /// M-of-N multi-key scheme using `AnyPublicKey` wrappers (variant 3).
    case multiKey = 3
    /// Account abstraction scheme (variant 5).
    case abstraction = 5
}

// MARK: - SigningSchemeInput

/// The subset of signing schemes that can be chosen when generating or importing an account.
///
/// This intentionally excludes legacy multi-key schemes; those are handled internally.
public enum SigningSchemeInput: Sendable, Hashable, Equatable {
    /// Ed25519 key (may be used with either the legacy `ed25519` scheme or the `singleKey` scheme).
    case ed25519
    /// Secp256k1 ECDSA key (always used with the `singleKey` scheme).
    case secp256k1Ecdsa
}

// MARK: - AuthenticationKey

/// A 32-byte key that controls on-chain account authentication.
///
/// An authentication key is derived from a public key and its associated signing scheme:
///
/// ```
/// authKey = SHA3-256(publicKeyBytes || signingScheme)
/// ```
///
/// For `MultiKey` accounts the pre-image uses the BCS-serialised `MultiKey` struct instead
/// of the raw public-key bytes:
///
/// ```
/// authKey = SHA3-256(bcs_serialize(multiKey) || SigningScheme.multiKey)
/// ```
///
/// The authentication key can be used directly as an account address via ``derivedAddress()``.
public struct AuthenticationKey: Sendable, Hashable, Equatable {

    // MARK: - Storage

    /// The raw 32 bytes of this authentication key.
    public let data: Data

    // MARK: - Initializers

    /// Create from exactly 32 raw bytes.
    ///
    /// - Throws: `AptosError.invalidArgument` if `data` is not 32 bytes.
    public init(data: Data) throws {
        guard data.count == ADDRESS_LENGTH else {
            throw AptosError.invalidArgument(
                "AuthenticationKey must be exactly \(ADDRESS_LENGTH) bytes, got \(data.count)"
            )
        }
        self.data = data
    }

    // MARK: - Derivation

    /// Derive an authentication key from raw public-key bytes and the associated signing scheme.
    ///
    /// This is the standard derivation formula used by all single-signer and `singleKey` accounts:
    ///
    /// ```
    /// SHA3-256(publicKeyBytes || signingScheme.rawValue)
    /// ```
    ///
    /// - Parameters:
    ///   - publicKeyBytes: The raw bytes of the public key (not BCS-encoded).
    ///   - scheme: The signing scheme that governs how the key is used on-chain.
    /// - Returns: A freshly derived `AuthenticationKey`.
    public static func fromPublicKeyBytes(
        _ publicKeyBytes: Data,
        scheme: SigningScheme
    ) -> AuthenticationKey {
        var preimage = publicKeyBytes
        preimage.append(scheme.rawValue)
        let digest = sha3_256(preimage)
        // sha3_256 always returns exactly 32 bytes, so the force-try is safe.
        return try! AuthenticationKey(data: digest)
    }

    /// Derive an authentication key from a BCS-serialisable multi-key object.
    ///
    /// The pre-image is the BCS encoding of the multi-key followed by the `multiKey` scheme byte:
    ///
    /// ```
    /// SHA3-256(bcs_serialize(multiKey) || SigningScheme.multiKey)
    /// ```
    ///
    /// - Parameter multiKey: Any `Serializable` value whose BCS encoding represents the multi-key.
    /// - Returns: A freshly derived `AuthenticationKey`.
    public static func fromMultiKey(_ multiKey: some Serializable) -> AuthenticationKey {
        var serializer = Serializer()
        multiKey.serialize(to: &serializer)
        var preimage = serializer.output()
        preimage.append(SigningScheme.multiKey.rawValue)
        let digest = sha3_256(preimage)
        return try! AuthenticationKey(data: digest)
    }

    // MARK: - Address Derivation

    /// Derive the account address that corresponds to this authentication key.
    ///
    /// On Aptos, a freshly created account has an address equal to its initial
    /// authentication key. This method returns that address.
    ///
    /// - Returns: An `AccountAddress` with the same 32 bytes as this key.
    public func derivedAddress() -> AccountAddress {
        // The authentication key bytes are exactly 32 bytes, so this is always valid.
        return try! AccountAddress(bytes: data)
    }

    // MARK: - Equatable / Hashable

    public static func == (lhs: AuthenticationKey, rhs: AuthenticationKey) -> Bool {
        lhs.data == rhs.data
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(data)
    }
}
