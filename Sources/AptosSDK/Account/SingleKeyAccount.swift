import Foundation

/// A single-key account using the `SigningScheme.singleKey` scheme.
///
/// Supports Ed25519, Secp256k1, and Secp256r1 private keys, all wrapped
/// in the `AnyPublicKey` authentication scheme.
public struct SingleKeyAccount: AptosAccount {
    public let accountAddress: AccountAddress
    public let signingScheme: SigningScheme = .singleKey

    private let _publicKey: AnyPublicKey
    private let _signer: @Sendable (Data) throws -> AnySignature

    public var publicKey: any AccountPublicKey {
        _publicKey
    }

    /// The `AnyPublicKey` wrapper for this account.
    public var anyPublicKey: AnyPublicKey { _publicKey }

    // MARK: - Ed25519

    /// Create from an Ed25519 private key (non-legacy SingleKey scheme).
    public init(privateKey: Ed25519PrivateKey) {
        let pubKey = privateKey.publicKey()
        self._publicKey = .ed25519(pubKey)
        // Auth key for SingleKey: SHA3-256(BCS(AnyPublicKey) || singleKey scheme)
        let authKey = AuthenticationKey.fromPublicKeyBytes(_publicKey.bcsToBytes(), scheme: .singleKey)
        self.accountAddress = authKey.derivedAddress()
        self._signer = { message in
            let sig = try privateKey.sign(message: message)
            return .ed25519(sig)
        }
    }

    // MARK: - Secp256k1

    /// Create from a Secp256k1 private key.
    public init(privateKey: Secp256k1PrivateKey) {
        let pubKey = privateKey.publicKey()
        self._publicKey = .secp256k1(pubKey)
        let authKey = AuthenticationKey.fromPublicKeyBytes(_publicKey.bcsToBytes(), scheme: .singleKey)
        self.accountAddress = authKey.derivedAddress()
        self._signer = { message in
            let sig = try privateKey.sign(message: message)
            return .secp256k1(sig)
        }
    }

    // MARK: - With explicit address

    /// Create with an explicit address (for rotated accounts).
    public init(privateKey: Ed25519PrivateKey, address: AccountAddress) {
        let pubKey = privateKey.publicKey()
        self._publicKey = .ed25519(pubKey)
        self.accountAddress = address
        self._signer = { message in
            let sig = try privateKey.sign(message: message)
            return .ed25519(sig)
        }
    }

    // MARK: - AptosAccount

    public func sign(message: Data) throws -> any AccountSignature {
        try _signer(message)
    }

    public func signWithAuthenticator(message: Data) throws -> AccountAuthenticator {
        let signature = try _signer(message)
        return .singleKey(publicKey: _publicKey, signature: signature)
    }
}

// MARK: - AnyPublicKey AccountPublicKey conformance

extension AnyPublicKey: AccountPublicKey {
    public func verify(message: Data, signature: any AccountSignature) throws -> Bool {
        switch self {
        case .ed25519(let key): return try key.verify(message: message, signature: signature)
        case .secp256k1(let key): return try key.verify(message: message, signature: signature)
        case .secp256r1(let key): return try key.verify(message: message, signature: signature)
        case .keyless, .federatedKeyless:
            throw AptosError.cryptoError("Keyless verification is handled on-chain")
        }
    }
}
