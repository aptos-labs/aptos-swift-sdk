import Foundation

// MARK: - AnyPrivateKey

/// A type-erased private key for export from SingleKeyAccount.
public enum AnyPrivateKey: Sendable {
    case ed25519(Ed25519PrivateKey)
    case secp256k1(Secp256k1PrivateKey)
    case secp256r1(Secp256r1PrivateKey)
}

// MARK: - SingleKeyAccount

/// A single-key account using the unified SingleKey authentication scheme.
///
/// Supports Ed25519, Secp256k1, and Secp256r1 key types.
public struct SingleKeyAccount: AptosAccount, Sendable {
    /// The public key wrapped as AnyPublicKey.
    public let publicKey: AnyPublicKey

    /// The account address.
    public let accountAddress: AccountAddress

    public let signingScheme = SigningScheme.singleKey

    public var publicKeyBytes: Data {
        (try? bcsToBytes(publicKey)) ?? Data()
    }

    /// The type-erased private key for export.
    public let privateKey: AnyPrivateKey

    /// Internal signing closure.
    private let signFunc: @Sendable (Data) throws -> AnySignature

    /// Creates an Ed25519 single-key account.
    public init(privateKey: Ed25519PrivateKey, address: AccountAddress? = nil) throws {
        let pubKey = try privateKey.publicKey()
        publicKey = .ed25519(pubKey)
        if let address {
            accountAddress = address
        } else {
            accountAddress = try AuthenticationKey.fromSingleKey(publicKey: publicKey).accountAddress()
        }
        self.privateKey = .ed25519(privateKey)
        let pk = privateKey
        signFunc = { message in
            let sig = try pk.sign(message)
            return .ed25519(sig)
        }
    }

    /// Creates a Secp256k1 single-key account.
    public init(privateKey: Secp256k1PrivateKey, address: AccountAddress? = nil) throws {
        let pubKey = try privateKey.publicKey()
        publicKey = .secp256k1(pubKey)
        if let address {
            accountAddress = address
        } else {
            accountAddress = try AuthenticationKey.fromSingleKey(publicKey: publicKey).accountAddress()
        }
        self.privateKey = .secp256k1(privateKey)
        let pk = privateKey
        signFunc = { message in
            let sig = try pk.sign(message)
            return .secp256k1(sig)
        }
    }

    /// Creates a Secp256r1 single-key account.
    public init(privateKey: Secp256r1PrivateKey, address: AccountAddress? = nil) throws {
        let pubKey = try privateKey.publicKey()
        publicKey = .secp256r1(pubKey)
        if let address {
            accountAddress = address
        } else {
            accountAddress = try AuthenticationKey.fromSingleKey(publicKey: publicKey).accountAddress()
        }
        self.privateKey = .secp256r1(privateKey)
        let pk = privateKey
        signFunc = { message in
            let sig = try pk.sign(message)
            return .webAuthn(WebAuthnSignature(
                signature: sig,
                authenticatorData: Data(),
                clientDataJSON: Data()
            ))
        }
    }

    /// Creates a SingleKey account from a BIP-39 mnemonic phrase.
    ///
    /// - For Ed25519: uses SLIP-0010 derivation with the default Aptos path.
    /// - For Secp256k1: uses BIP-32 derivation with the default Aptos Secp256k1 path.
    public static func fromMnemonic(
        _ phrase: String,
        scheme: SigningSchemeInput = .ed25519,
        path: String? = nil,
        passphrase: String = ""
    ) throws -> Self {
        let seed = try Mnemonic.toSeed(phrase, passphrase: passphrase)
        switch scheme {
        case .ed25519:
            let derivePath = path ?? DerivationPath.defaultAptos
            let (key, _) = try SLIP0010.derivePath(derivePath, seed: seed)
            return try Self(privateKey: Ed25519PrivateKey(data: key))
        case .secp256k1Ecdsa:
            let derivePath = path ?? DerivationPath.defaultAptosSecp256k1
            let (key, _) = try BIP32.derivePath(derivePath, seed: seed)
            return try Self(privateKey: Secp256k1PrivateKey(data: key))
        case .secp256r1Ecdsa:
            throw AptosError.crypto(.unsupportedScheme(
                "Mnemonic derivation not supported for Secp256r1"
            ))
        }
    }

    /// Generates a new single-key account with the specified scheme.
    public static func generate(scheme: SigningSchemeInput = .ed25519) throws -> Self {
        switch scheme {
        case .ed25519:
            try Self(privateKey: Ed25519PrivateKey.generate())
        case .secp256k1Ecdsa:
            try Self(privateKey: Secp256k1PrivateKey.generate())
        case .secp256r1Ecdsa:
            try Self(privateKey: Secp256r1PrivateKey.generate())
        }
    }

    // MARK: - AptosAccount

    public func sign(message: Data) throws -> AnySignature {
        try signFunc(message)
    }

    public func signWithAuthenticator(message: Data) throws -> AccountAuthenticator {
        let sig = try sign(message: message)
        return .singleKey(publicKey: publicKey, signature: sig)
    }

    public func authenticationKey() throws -> AuthenticationKey {
        try AuthenticationKey.fromSingleKey(publicKey: publicKey)
    }
}
