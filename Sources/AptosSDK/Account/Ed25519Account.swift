import Foundation

/// A legacy Ed25519 single-key account.
///
/// Uses the `SigningScheme.ed25519` scheme where the authentication key is
/// derived directly from the Ed25519 public key: `SHA3-256(pubkey || 0x00)`.
public struct Ed25519Account: AptosAccount {
    public let privateKey: Ed25519PrivateKey
    public let accountAddress: AccountAddress
    public let signingScheme: SigningScheme = .ed25519

    public var publicKey: any AccountPublicKey {
        privateKey.publicKey()
    }

    /// Create from an existing private key.
    public init(privateKey: Ed25519PrivateKey) {
        self.privateKey = privateKey
        let pubKey = privateKey.publicKey()
        let authKey = AuthenticationKey.fromPublicKeyBytes(pubKey.data, scheme: .ed25519)
        self.accountAddress = authKey.derivedAddress()
    }

    /// Create from an existing private key with a specific address (e.g. after key rotation).
    public init(privateKey: Ed25519PrivateKey, address: AccountAddress) {
        self.privateKey = privateKey
        self.accountAddress = address
    }

    public func sign(message: Data) throws -> any AccountSignature {
        try privateKey.sign(message: message)
    }

    public func signWithAuthenticator(message: Data) throws -> AccountAuthenticator {
        let signature = try privateKey.sign(message: message)
        return .ed25519(publicKey: privateKey.publicKey(), signature: signature)
    }
}
