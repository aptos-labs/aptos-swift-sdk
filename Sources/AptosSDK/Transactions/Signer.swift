import Foundation

/// Transaction signing utilities.
///
/// Provides static methods for signing transactions and assembling
/// `SignedTransaction` values ready for on-chain submission.
public enum TransactionSigner {
    /// Signs a transaction with a single account, returning the sender's authenticator.
    ///
    /// - Parameters:
    ///   - transaction: The transaction to sign (simple or multi-agent).
    ///   - signer: The account that will sign the transaction.
    /// - Returns: An `AccountAuthenticator` containing the signer's public key and signature.
    public static func sign(
        transaction: AnyRawTransaction,
        signer: any AptosAccount
    ) throws -> AccountAuthenticator {
        let message = try transaction.signingMessage()
        return try signer.signWithAuthenticator(message: message)
    }

    /// Signs a transaction as a fee payer (sponsor).
    ///
    /// - Parameters:
    ///   - transaction: The transaction to sign.
    ///   - feePayer: The account that will pay gas fees for this transaction.
    /// - Returns: An `AccountAuthenticator` for the fee payer.
    public static func signAsFeePayer(
        transaction: AnyRawTransaction,
        feePayer: any AptosAccount
    ) throws -> AccountAuthenticator {
        let message = try transaction.signingMessage()
        return try feePayer.signWithAuthenticator(message: message)
    }

    /// Creates a signed transaction from a simple (single-signer) transaction.
    ///
    /// - Parameters:
    ///   - transaction: The simple transaction containing the raw transaction and optional fee payer address.
    ///   - senderAuthenticator: The sender's authenticator produced by ``sign(transaction:signer:)``.
    ///   - feePayerAuthenticator: The fee payer's authenticator, required when `transaction.feePayerAddress` is set.
    /// - Returns: A `SignedTransaction` ready for BCS encoding and on-chain submission.
    /// - Throws: `AptosError.transaction(.invalidAuthenticator)` if the fee payer authenticator is
    ///   provided without a fee payer address (or vice versa).
    public static func createSignedTransaction(
        transaction: SimpleTransaction,
        senderAuthenticator: AccountAuthenticator,
        feePayerAuthenticator: AccountAuthenticator? = nil
    ) throws -> SignedTransaction {
        if transaction.feePayerAddress != nil, feePayerAuthenticator == nil {
            throw AptosError.transaction(.invalidAuthenticator(
                "feePayerAuthenticator is required when feePayerAddress is set"
            ))
        }
        if transaction.feePayerAddress == nil, feePayerAuthenticator != nil {
            throw AptosError.transaction(.invalidAuthenticator(
                "feePayerAuthenticator provided without feePayerAddress"
            ))
        }

        let txAuth: TransactionAuthenticator = if let feePayer = transaction.feePayerAddress,
                                                  let feePayerAuth = feePayerAuthenticator {
            .feePayer(
                sender: senderAuthenticator,
                secondarySignerAddresses: [],
                secondarySigners: [],
                feePayerAddress: feePayer,
                feePayerAuthenticator: feePayerAuth
            )
        } else {
            switch senderAuthenticator {
            case let .ed25519(pubKey, sig):
                .ed25519(publicKey: pubKey, signature: sig)
            case let .multiEd25519(pubKey, sig):
                .multiEd25519(publicKey: pubKey, signature: sig)
            default:
                .singleSender(senderAuthenticator)
            }
        }

        return SignedTransaction(
            rawTransaction: transaction.rawTransaction,
            authenticator: txAuth
        )
    }

    /// Creates a signed transaction from a multi-agent transaction.
    ///
    /// - Parameters:
    ///   - transaction: The multi-agent transaction containing secondary signer addresses.
    ///   - senderAuthenticator: The primary sender's authenticator.
    ///   - secondaryAuthenticators: Authenticators from each secondary signer, in the same order
    ///     as `transaction.secondarySignerAddresses`.
    ///   - feePayerAuthenticator: The fee payer's authenticator, required when `transaction.feePayerAddress` is set.
    /// - Returns: A `SignedTransaction` ready for BCS encoding and on-chain submission.
    /// - Throws: `AptosError.transaction(.invalidAuthenticator)` if counts don't match or fee payer
    ///   state is inconsistent.
    public static func createMultiAgentSignedTransaction(
        transaction: MultiAgentTransaction,
        senderAuthenticator: AccountAuthenticator,
        secondaryAuthenticators: [AccountAuthenticator],
        feePayerAuthenticator: AccountAuthenticator? = nil
    ) throws -> SignedTransaction {
        guard secondaryAuthenticators.count == transaction.secondarySignerAddresses.count else {
            throw AptosError.transaction(.invalidAuthenticator(
                "secondaryAuthenticators count (\(secondaryAuthenticators.count)) must match secondarySignerAddresses count (\(transaction.secondarySignerAddresses.count))"
            ))
        }
        if transaction.feePayerAddress != nil, feePayerAuthenticator == nil {
            throw AptosError.transaction(.invalidAuthenticator(
                "feePayerAuthenticator is required when feePayerAddress is set"
            ))
        }
        if transaction.feePayerAddress == nil, feePayerAuthenticator != nil {
            throw AptosError.transaction(.invalidAuthenticator(
                "feePayerAuthenticator provided without feePayerAddress"
            ))
        }

        let txAuth: TransactionAuthenticator = if let feePayer = transaction.feePayerAddress,
                                                  let feePayerAuth = feePayerAuthenticator {
            .feePayer(
                sender: senderAuthenticator,
                secondarySignerAddresses: transaction.secondarySignerAddresses,
                secondarySigners: secondaryAuthenticators,
                feePayerAddress: feePayer,
                feePayerAuthenticator: feePayerAuth
            )
        } else {
            .multiAgent(
                sender: senderAuthenticator,
                secondarySignerAddresses: transaction.secondarySignerAddresses,
                secondarySigners: secondaryAuthenticators
            )
        }

        return SignedTransaction(
            rawTransaction: transaction.rawTransaction,
            authenticator: txAuth
        )
    }
}
