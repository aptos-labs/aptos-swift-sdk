import Foundation

/// Protocol that all Aptos account types must implement.
public protocol AptosAccount: Sendable {
    /// The account address.
    var accountAddress: AccountAddress { get }

    /// The signing scheme used by this account.
    var signingScheme: SigningScheme { get }

    /// Signs a raw message.
    func sign(message: Data) throws -> AnySignature

    /// Signs a transaction and returns the appropriate account authenticator.
    func signWithAuthenticator(message: Data) throws -> AccountAuthenticator

    /// Returns the authentication key for this account.
    func authenticationKey() throws -> AuthenticationKey
}
