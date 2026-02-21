import Foundation

// MARK: - KeylessAccount

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
    public var proof: Data

    /// Optional proof expiry (Unix timestamp in seconds).
    public var proofExpiryDateSecs: UInt64?

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
    ///   - proofExpiryDateSecs: Optional expiry for the proof
    ///   - address: Optional override address (for rotated accounts)
    public init(
        issuer: String,
        ephemeralKeyPair: EphemeralKeyPair,
        proof: Data,
        jwt: String,
        pepper: Data,
        uidKey: String = "sub",
        uidVal: String,
        proofExpiryDateSecs: UInt64? = nil,
        address: AccountAddress? = nil
    ) throws {
        self.ephemeralKeyPair = ephemeralKeyPair
        self.proof = proof
        self.jwt = jwt
        self.pepper = pepper
        self.uidKey = uidKey
        self.uidVal = uidVal
        self.proofExpiryDateSecs = proofExpiryDateSecs

        // Compute identity commitment: SHA3-256(pepper || uidKey || uidVal)
        var commitData = Data()
        commitData.append(pepper)
        commitData.append(Data(uidKey.utf8))
        commitData.append(Data(uidVal.utf8))
        let idCommitment = Data(SHA3.sha256(Array(commitData)))

        keylessPublicKey = KeylessPublicKey(issuer: issuer, idCommitment: idCommitment)

        if let address {
            accountAddress = address
        } else {
            let anyPubKey = AnyPublicKey.keyless(keylessPublicKey)
            let authKey = try AuthenticationKey.fromSingleKey(publicKey: anyPubKey)
            accountAddress = authKey.accountAddress()
        }
    }

    /// Whether the proof has expired.
    public var isProofExpired: Bool {
        guard let expiry = proofExpiryDateSecs else { return false }
        return UInt64(Date().timeIntervalSince1970) >= expiry
    }

    /// Whether the JWT has expired (based on `exp` claim).
    public var isJWTExpired: Bool {
        guard let exp = Self.extractJWTExpiry(jwt) else { return false }
        return UInt64(Date().timeIntervalSince1970) >= exp
    }

    /// Whether the ephemeral key pair, proof, or JWT has expired.
    public var isExpired: Bool {
        ephemeralKeyPair.isExpired || isProofExpired || isJWTExpired
    }

    /// Refreshes the proof using the keyless API.
    public mutating func refreshProof(using keylessAPI: KeylessAPI) async throws {
        let newProof = try await keylessAPI.getProof(
            jwt: jwt,
            ephemeralPublicKey: ephemeralKeyPair.publicKey.data,
            pepper: pepper,
            uidKey: uidKey
        )
        proof = newProof
        proofExpiryDateSecs = nil
    }

    /// Refreshes the proof only if it has expired.
    @discardableResult
    public mutating func refreshProofIfNeeded(using keylessAPI: KeylessAPI) async throws -> Bool {
        guard isProofExpired else { return false }
        try await refreshProof(using: keylessAPI)
        return true
    }

    /// Extracts the `exp` claim from a JWT payload via base64url decoding.
    private static func extractJWTExpiry(_ jwt: String) -> UInt64? {
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var base64 = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        // Pad to multiple of 4
        while base64.count % 4 != 0 {
            base64.append("=")
        }
        guard let data = Data(base64Encoded: base64) else { return nil }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        if let exp = json["exp"] as? UInt64 {
            return exp
        }
        if let exp = json["exp"] as? Int {
            return UInt64(exp)
        }
        if let exp = json["exp"] as? Double {
            return UInt64(exp)
        }
        return nil
    }
}

// MARK: AptosAccount

extension KeylessAccount: AptosAccount {
    public var signingScheme: SigningScheme {
        .singleKey
    }

    public var publicKeyBytes: Data {
        let anyPubKey = AnyPublicKey.keyless(keylessPublicKey)
        return (try? bcsToBytes(anyPubKey)) ?? Data()
    }

    public func sign(message: Data) throws -> AnySignature {
        guard !ephemeralKeyPair.isExpired else {
            throw AptosError.keyless(.invalidConfiguration("Keyless account ephemeral key has expired"))
        }
        if isProofExpired {
            throw AptosError.keyless(.proofExpired("Proof has expired"))
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
