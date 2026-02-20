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
        self.publicKey = try privateKey.publicKey()
        if let address {
            self.accountAddress = address
        } else {
            let authKey = AuthenticationKey.fromEd25519(publicKey: self.publicKey)
            self.accountAddress = authKey.accountAddress()
        }
    }

    /// Generates a new random Ed25519 account.
    public static func generate() throws -> Ed25519Account {
        let privateKey = Ed25519PrivateKey.generate()
        return try Ed25519Account(privateKey: privateKey)
    }

    /// Creates from a hex private key string.
    public static func fromPrivateKey(_ hex: String) throws -> Ed25519Account {
        let key = try Ed25519PrivateKey.fromHex(hex)
        return try Ed25519Account(privateKey: key)
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
