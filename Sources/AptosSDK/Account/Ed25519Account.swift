import Foundation

/// An Ed25519 account using the legacy signing scheme.
public struct Ed25519Account: AptosAccount, Sendable {
    /// The Ed25519 private key.
    public let privateKey: Ed25519PrivateKey

    /// The Ed25519 public key.
    public let publicKey: Ed25519PublicKey

    /// The account address derived from the authentication key.
    public let accountAddress: AccountAddress

    public let signingScheme = SigningScheme.ed25519

    public var publicKeyBytes: Data {
        publicKey.data
    }

    /// Creates an account from an existing private key.
    public init(privateKey: Ed25519PrivateKey, address: AccountAddress? = nil) throws {
        self.privateKey = privateKey
        publicKey = try privateKey.publicKey()
        if let address {
            accountAddress = address
        } else {
            let authKey = AuthenticationKey.fromEd25519(publicKey: publicKey)
            accountAddress = authKey.accountAddress()
        }
    }

    /// Generates a new random Ed25519 account.
    public static func generate() throws -> Self {
        let privateKey = Ed25519PrivateKey.generate()
        return try Self(privateKey: privateKey)
    }

    /// Creates from a hex private key string.
    public static func fromPrivateKey(_ hex: String) throws -> Self {
        let key = try Ed25519PrivateKey.fromHex(hex)
        return try Self(privateKey: key)
    }

    /// Creates an Ed25519 account from a BIP-39 mnemonic phrase using SLIP-0010 derivation.
    ///
    /// - Parameters:
    ///   - phrase: A valid BIP-39 mnemonic phrase.
    ///   - path: The derivation path (default: m/44'/637'/0'/0'/0').
    ///   - passphrase: Optional BIP-39 passphrase (default: empty string).
    public static func fromMnemonic(
        _ phrase: String,
        path: String = DerivationPath.defaultAptos,
        passphrase: String = ""
    ) throws -> Self {
        let seed = try Mnemonic.toSeed(phrase, passphrase: passphrase)
        let (key, _) = try SLIP0010.derivePath(path, seed: seed)
        let privateKey = try Ed25519PrivateKey(data: key)
        return try Self(privateKey: privateKey)
    }

    // MARK: - AptosAccount

    public func sign(message: Data) throws -> AnySignature {
        let sig = try privateKey.sign(message)
        return .ed25519(sig)
    }

    public func signWithAuthenticator(message: Data) throws -> AccountAuthenticator {
        let sig = try privateKey.sign(message)
        return .ed25519(publicKey: publicKey, signature: sig)
    }

    public func authenticationKey() throws -> AuthenticationKey {
        AuthenticationKey.fromEd25519(publicKey: publicKey)
    }
}
