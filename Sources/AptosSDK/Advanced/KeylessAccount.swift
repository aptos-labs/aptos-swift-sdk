import Foundation

/// A keyless account that uses OIDC (e.g., Google, Apple) for authentication.
///
/// Keyless accounts derive their address from the OIDC issuer, audience, and user ID,
/// combined with a pepper from the Aptos pepper service. Transactions are signed using
/// an ephemeral key pair, with a zero-knowledge proof that the user owns the OIDC identity.
///
/// ## Authentication Key Derivation
///
/// ```
/// idCommitment = SHA3-256(pepper || uidKey || uidVal)
/// keylessPublicKey = KeylessPublicKey(iss, idCommitment)
/// anyPublicKey = AnyPublicKey.keyless(keylessPublicKey)
/// authKey = SHA3-256(BCS(anyPublicKey) || signingScheme.singleKey)
/// address = authKey
/// ```
public struct KeylessAccount: Sendable {
    /// The keyless public key.
    public let keylessPublicKey: KeylessPublicKey

    /// The account address.
    public let accountAddress: AccountAddress

    /// The ephemeral key pair used for signing.
    public let ephemeralKeyPair: EphemeralKeyPair

    /// The zero-knowledge proof from the prover service.
    public let proof: Data

    /// The OIDC JWT token.
    public let jwt: String

    /// The pepper from the pepper service.
    public let pepper: Data

    /// The UID key (e.g., "sub" or "email").
    public let uidKey: String

    /// The UID value from the JWT.
    public let uidVal: String

    /// Creates a keyless account from OIDC components.
    ///
    /// - Parameters:
    ///   - issuer: The OIDC issuer (e.g., "https://accounts.google.com")
    ///   - ephemeralKeyPair: The short-lived signing key
    ///   - proof: The zero-knowledge proof from the prover service
    ///   - jwt: The OIDC JWT token
    ///   - pepper: The pepper from the pepper service (31 bytes)
    ///   - uidKey: The JWT claim key for the user ID (default: "sub")
    ///   - uidVal: The user ID value from the JWT
    ///   - address: Optional override address (for rotated accounts)
    public init(
        issuer: String,
        ephemeralKeyPair: EphemeralKeyPair,
        proof: Data,
        jwt: String,
        pepper: Data,
        uidKey: String = "sub",
        uidVal: String,
        address: AccountAddress? = nil
    ) throws {
        self.ephemeralKeyPair = ephemeralKeyPair
        self.proof = proof
        self.jwt = jwt
        self.pepper = pepper
        self.uidKey = uidKey
        self.uidVal = uidVal

        // Compute identity commitment: SHA3-256(pepper || uidKey || uidVal)
        var commitData = Data()
        commitData.append(pepper)
        commitData.append(Data(uidKey.utf8))
        commitData.append(Data(uidVal.utf8))
        let idCommitment = Data(SHA3.sha256(Array(commitData)))

        self.keylessPublicKey = KeylessPublicKey(issuer: issuer, idCommitment: idCommitment)

        if let address {
            self.accountAddress = address
        } else {
            let anyPubKey = AnyPublicKey.keyless(keylessPublicKey)
            let authKey = try AuthenticationKey.fromSingleKey(publicKey: anyPubKey)
            self.accountAddress = authKey.accountAddress()
        }
    }

    /// Whether the ephemeral key pair has expired.
    public var isExpired: Bool {
        ephemeralKeyPair.isExpired
    }
}

extension KeylessAccount: AptosAccount {
    public var signingScheme: SigningScheme { .singleKey }

    public func sign(message: Data) throws -> AnySignature {
        guard !isExpired else {
            throw AptosError.keyless(.invalidConfiguration("Keyless account ephemeral key has expired"))
        }
        let ephemeralSig = try ephemeralKeyPair.sign(message)

        // The keyless signature wraps the ephemeral signature and the ZK proof
        var sigData = Data()
        sigData.append(ephemeralSig.data)
        sigData.append(proof)

        return .keyless(KeylessSignature(data: sigData))
    }

    public func signWithAuthenticator(message: Data) throws -> AccountAuthenticator {
        let sig = try sign(message: message)
        let anyPubKey = AnyPublicKey.keyless(keylessPublicKey)
        return .singleKey(publicKey: anyPubKey, signature: sig)
    }

    public func authenticationKey() throws -> AuthenticationKey {
        let anyPubKey = AnyPublicKey.keyless(keylessPublicKey)
        return try AuthenticationKey.fromSingleKey(publicKey: anyPubKey)
    }
}
