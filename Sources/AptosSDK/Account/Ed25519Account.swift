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
