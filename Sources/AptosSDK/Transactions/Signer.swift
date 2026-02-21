import Foundation

/// Transaction signing utilities.
public enum TransactionSigner {
    /// Signs a transaction with a single account.
    public static func sign(
        transaction: AnyRawTransaction,
        signer: any AptosAccount
    ) throws -> AccountAuthenticator {
        let message = try transaction.signingMessage()
        return try signer.signWithAuthenticator(message: message)
    }

    /// Signs a transaction as a fee payer.
    public static func signAsFeePayer(
        transaction: AnyRawTransaction,
        feePayer: any AptosAccount
    ) throws -> AccountAuthenticator {
        let message = try transaction.signingMessage()
        return try feePayer.signWithAuthenticator(message: message)
    }

    /// Creates a signed transaction from a simple transaction.
    public static func createSignedTransaction(
        transaction: SimpleTransaction,
        senderAuthenticator: AccountAuthenticator,
        feePayerAuthenticator: AccountAuthenticator? = nil
    ) throws -> SignedTransaction {
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
    public static func createMultiAgentSignedTransaction(
        transaction: MultiAgentTransaction,
        senderAuthenticator: AccountAuthenticator,
        secondaryAuthenticators: [AccountAuthenticator],
        feePayerAuthenticator: AccountAuthenticator? = nil
    ) throws -> SignedTransaction {
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
