import Foundation

/// Utilities for building and signing fee-payer (sponsored) transactions.
///
/// Fee-payer transactions allow a third party to pay the gas fees for a transaction.
/// The sender signs the transaction as if the fee payer address is `0x0` initially,
/// then the fee payer signs with the actual fee payer address.
///
/// ## Signing Flow
///
/// 1. Build a `SimpleTransaction` with `feePayerAddress` set.
/// 2. The sender signs the signing message (which includes the fee payer address).
/// 3. The fee payer signs the same signing message.
/// 4. Combine both authenticators into a `TransactionAuthenticator.feePayer`.
/// 5. Create a `SignedTransaction` for submission.
public enum FeePayerUtils {
    /// Builds a fee-payer simple transaction.
    ///
    /// - Parameters:
    ///   - rawTransaction: The raw transaction from the sender
    ///   - feePayerAddress: The address of the fee payer
    /// - Returns: A simple transaction with fee payer set
    public static func buildFeePayerTransaction(
        rawTransaction: RawTransaction,
        feePayerAddress: AccountAddress
    ) -> SimpleTransaction {
        SimpleTransaction(
            rawTransaction: rawTransaction,
            feePayerAddress: feePayerAddress
        )
    }

    /// Signs a fee-payer transaction with both sender and fee payer.
    ///
    /// - Parameters:
    ///   - transaction: The simple transaction with fee payer address
    ///   - sender: The sender account
    ///   - feePayer: The fee payer account
    /// - Returns: A signed transaction ready for submission
    public static func signFeePayerTransaction(
        transaction: SimpleTransaction,
        sender: any AptosAccount,
        feePayer: any AptosAccount
    ) throws -> SignedTransaction {
        guard let feePayerAddress = transaction.feePayerAddress else {
            throw AptosError.transaction(.buildFailed("Transaction does not have a fee payer address"))
        }
        guard feePayerAddress == feePayer.accountAddress else {
            throw AptosError.transaction(.invalidAuthenticator(
                "feePayer account address does not match transaction.feePayerAddress"
            ))
        }

        let senderAuth = try TransactionSigner.sign(
            transaction: .simple(transaction),
            signer: sender
        )

        let feePayerAuth = try TransactionSigner.signAsFeePayer(
            transaction: .simple(transaction),
            feePayer: feePayer
        )

        return try TransactionSigner.createSignedTransaction(
            transaction: transaction,
            senderAuthenticator: senderAuth,
            feePayerAuthenticator: feePayerAuth
        )
    }

    /// Builds a fee-payer multi-agent transaction.
    ///
    /// - Parameters:
    ///   - rawTransaction: The raw transaction from the primary sender
    ///   - secondarySignerAddresses: Addresses of secondary signers
    ///   - feePayerAddress: The address of the fee payer
    /// - Returns: A multi-agent transaction with fee payer set
    public static func buildFeePayerMultiAgentTransaction(
        rawTransaction: RawTransaction,
        secondarySignerAddresses: [AccountAddress],
        feePayerAddress: AccountAddress
    ) -> MultiAgentTransaction {
        MultiAgentTransaction(
            rawTransaction: rawTransaction,
            secondarySignerAddresses: secondarySignerAddresses,
            feePayerAddress: feePayerAddress
        )
    }
}
