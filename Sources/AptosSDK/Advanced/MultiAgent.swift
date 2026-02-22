import Foundation

/// Utilities for building and signing multi-agent transactions.
///
/// Multi-agent transactions involve multiple signers. The primary signer pays
/// for gas while secondary signers authorize their participation. All signers
/// sign the same signing message that includes the full list of secondary addresses.
///
/// ## Signing Flow
///
/// 1. Build a `MultiAgentTransaction` with the sender's raw transaction and secondary addresses.
/// 2. Each signer (primary + secondary) computes the signing message and signs it.
/// 3. Combine all authenticators into a `TransactionAuthenticator.multiAgent`.
/// 4. Create a `SignedTransaction` for submission.
public enum MultiAgentUtils {
    /// Builds a multi-agent transaction from a raw transaction.
    ///
    /// - Parameters:
    ///   - rawTransaction: The raw transaction from the primary sender
    ///   - secondarySignerAddresses: Addresses of all secondary signers
    ///   - feePayerAddress: Optional fee payer address (if using sponsored transactions)
    /// - Returns: A multi-agent transaction ready for signing
    public static func buildMultiAgentTransaction(
        rawTransaction: RawTransaction,
        secondarySignerAddresses: [AccountAddress],
        feePayerAddress: AccountAddress? = nil
    ) -> MultiAgentTransaction {
        MultiAgentTransaction(
            rawTransaction: rawTransaction,
            secondarySignerAddresses: secondarySignerAddresses,
            feePayerAddress: feePayerAddress
        )
    }

    /// Signs a multi-agent transaction with all signers.
    ///
    /// - Parameters:
    ///   - transaction: The multi-agent transaction
    ///   - sender: The primary signer account
    ///   - secondarySigners: The secondary signer accounts (in order matching addresses)
    ///   - feePayer: Optional fee payer account
    /// - Returns: A signed transaction ready for submission
    public static func signMultiAgentTransaction(
        transaction: MultiAgentTransaction,
        sender: any AptosAccount,
        secondarySigners: [any AptosAccount],
        feePayer: (any AptosAccount)? = nil
    ) throws -> SignedTransaction {
        guard secondarySigners.count == transaction.secondarySignerAddresses.count else {
            throw AptosError.transaction(.invalidAuthenticator(
                "secondarySigners count (\(secondarySigners.count)) must match secondarySignerAddresses count (\(transaction.secondarySignerAddresses.count))"
            ))
        }
        if transaction.feePayerAddress != nil, feePayer == nil {
            throw AptosError.transaction(.invalidAuthenticator(
                "Transaction includes feePayerAddress but no feePayer account was provided"
            ))
        }
        if transaction.feePayerAddress == nil, feePayer != nil {
            throw AptosError.transaction(.invalidAuthenticator(
                "feePayer account provided without a feePayerAddress in the transaction"
            ))
        }
        if let feePayerAddress = transaction.feePayerAddress,
           let feePayer,
           feePayer.accountAddress != feePayerAddress {
            throw AptosError.transaction(.invalidAuthenticator(
                "feePayer.accountAddress does not match transaction.feePayerAddress"
            ))
        }

        // All signers sign the same signing message
        let senderAuth = try TransactionSigner.sign(
            transaction: .multiAgent(transaction),
            signer: sender
        )

        var secondaryAuths: [AccountAuthenticator] = []
        for signer in secondarySigners {
            let auth = try TransactionSigner.sign(
                transaction: .multiAgent(transaction),
                signer: signer
            )
            secondaryAuths.append(auth)
        }

        let feePayerAuth: AccountAuthenticator? = if let feePayer {
            try TransactionSigner.signAsFeePayer(
                transaction: .multiAgent(transaction),
                feePayer: feePayer
            )
        } else {
            nil
        }

        return try TransactionSigner.createMultiAgentSignedTransaction(
            transaction: transaction,
            senderAuthenticator: senderAuth,
            secondaryAuthenticators: secondaryAuths,
            feePayerAuthenticator: feePayerAuth
        )
    }
}
