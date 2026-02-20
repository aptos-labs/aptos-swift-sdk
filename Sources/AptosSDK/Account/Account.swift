import Foundation

/// The core account protocol. All account types conform to this.
public protocol AptosAccount: Sendable {
    /// The on-chain address of this account.
    var accountAddress: AccountAddress { get }

    /// The public key associated with this account.
    var publicKey: any AccountPublicKey { get }

    /// The signing scheme used by this account.
    var signingScheme: SigningScheme { get }

    /// Sign a raw message.
    func sign(message: Data) throws -> any AccountSignature

    /// Sign a transaction, returning a raw signature.
    func signTransaction(_ transaction: AnyRawTransaction) throws -> any AccountSignature

    /// Sign a message and wrap in an AccountAuthenticator.
    func signWithAuthenticator(message: Data) throws -> AccountAuthenticator

    /// Sign a transaction and wrap in an AccountAuthenticator.
    func signTransactionWithAuthenticator(_ transaction: AnyRawTransaction) throws -> AccountAuthenticator
}

/// Default implementations for AptosAccount.
extension AptosAccount {
    public func signTransaction(_ transaction: AnyRawTransaction) throws -> any AccountSignature {
        let message = transaction.signingMessage()
        return try sign(message: message)
    }

    public func signTransactionWithAuthenticator(
        _ transaction: AnyRawTransaction
    ) throws -> AccountAuthenticator {
        let message = transaction.signingMessage()
        return try signWithAuthenticator(message: message)
    }
}

// MARK: - Account Factory

/// Factory for creating accounts.
public enum AccountFactory {
    /// Generate a new account with a random private key.
    ///
    /// - Parameters:
    ///   - scheme: The key algorithm to use. Defaults to `.ed25519`.
    ///   - legacy: If `true` (default) and scheme is `.ed25519`, creates an `Ed25519Account`.
    ///             If `false`, creates a `SingleKeyAccount`.
    /// - Returns: A new account ready for use.
    public static func generate(
        scheme: SigningSchemeInput = .ed25519,
        legacy: Bool = true
    ) -> any AptosAccount {
        switch scheme {
        case .ed25519:
            let privateKey = Ed25519PrivateKey.generate()
            if legacy {
                return Ed25519Account(privateKey: privateKey)
            }
            return SingleKeyAccount(privateKey: privateKey)

        case .secp256k1Ecdsa:
            let privateKey = Secp256k1PrivateKey.generate()
            return SingleKeyAccount(privateKey: privateKey)
        }
    }

    /// Create an account from an existing private key.
    public static func fromPrivateKey(
        _ privateKey: Ed25519PrivateKey,
        legacy: Bool = true
    ) -> any AptosAccount {
        if legacy {
            return Ed25519Account(privateKey: privateKey)
        }
        return SingleKeyAccount(privateKey: privateKey)
    }

    /// Create an account from an existing secp256k1 private key.
    public static func fromPrivateKey(_ privateKey: Secp256k1PrivateKey) -> SingleKeyAccount {
        SingleKeyAccount(privateKey: privateKey)
    }

}
