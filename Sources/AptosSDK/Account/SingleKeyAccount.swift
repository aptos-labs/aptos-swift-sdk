import Foundation

/// A single-key account using the unified SingleKey authentication scheme.
///
/// Supports Ed25519, Secp256k1, and Secp256r1 key types.
public struct SingleKeyAccount: AptosAccount, Sendable {
    /// The public key wrapped as AnyPublicKey.
    public let publicKey: AnyPublicKey

    /// The account address.
    public let accountAddress: AccountAddress

    public let signingScheme = SigningScheme.singleKey

    // Internal storage for the private key
    private let signFunc: @Sendable (Data) throws -> AnySignature

    /// Creates an Ed25519 single-key account.
    public init(privateKey: Ed25519PrivateKey, address: AccountAddress? = nil) throws {
        let pubKey = try privateKey.publicKey()
        self.publicKey = .ed25519(pubKey)
        if let address {
            self.accountAddress = address
        } else {
            self.accountAddress = try AuthenticationKey.fromSingleKey(publicKey: self.publicKey).accountAddress()
        }
        let pk = privateKey
        self.signFunc = { message in
            let sig = try pk.sign(message)
            return .ed25519(sig)
        }
    }

    /// Creates a Secp256k1 single-key account.
    public init(privateKey: Secp256k1PrivateKey, address: AccountAddress? = nil) throws {
        let pubKey = try privateKey.publicKey()
        self.publicKey = .secp256k1(pubKey)
        if let address {
            self.accountAddress = address
        } else {
            self.accountAddress = try AuthenticationKey.fromSingleKey(publicKey: self.publicKey).accountAddress()
        }
        let pk = privateKey
        self.signFunc = { message in
            let sig = try pk.sign(message)
            return .secp256k1(sig)
        }
    }

    /// Creates a Secp256r1 single-key account.
    public init(privateKey: Secp256r1PrivateKey, address: AccountAddress? = nil) throws {
        let pubKey = try privateKey.publicKey()
        self.publicKey = .secp256r1(pubKey)
        if let address {
            self.accountAddress = address
        } else {
            self.accountAddress = try AuthenticationKey.fromSingleKey(publicKey: self.publicKey).accountAddress()
        }
        let pk = privateKey
        self.signFunc = { message in
            let sig = try pk.sign(message)
            return .webAuthn(WebAuthnSignature(
                signature: sig,
                authenticatorData: Data(),
                clientDataJSON: Data()
            ))
        }
    }

    /// Generates a new single-key account with the specified scheme.
    public static func generate(scheme: SigningSchemeInput = .ed25519) throws -> SingleKeyAccount {
        switch scheme {
        case .ed25519:
            return try SingleKeyAccount(privateKey: Ed25519PrivateKey.generate())
        case .secp256k1Ecdsa:
            return try SingleKeyAccount(privateKey: Secp256k1PrivateKey.generate())
        case .secp256r1Ecdsa:
            return try SingleKeyAccount(privateKey: Secp256r1PrivateKey.generate())
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
