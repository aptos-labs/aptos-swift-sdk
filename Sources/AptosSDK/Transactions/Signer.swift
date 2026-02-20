import Foundation

/// Transaction signing utilities.
public enum TransactionSigner {
    /// Sign a transaction with a single signer.
    public static func sign(
        signer: any AptosAccount,
        transaction: AnyRawTransaction
    ) throws -> AccountAuthenticator {
        try signer.signTransactionWithAuthenticator(transaction)
    }

    /// Build the signed transaction BCS bytes for submission.
    public static func buildSignedTransaction(
        transaction: AnyRawTransaction,
        senderAuthenticator: AccountAuthenticator,
        feePayerAuthenticator: AccountAuthenticator? = nil,
        additionalSignersAuthenticators: [AccountAuthenticator]? = nil
    ) throws -> SignedTransaction {
        let rawTxn = transaction.rawTransaction

        let transactionAuthenticator: TransactionAuthenticator

        switch transaction {
        case .simple(let simple):
            if let feePayerAddress = simple.feePayerAddress, let fpAuth = feePayerAuthenticator {
                transactionAuthenticator = .feePayer(FeePayerAuthenticator(
                    senderAuthenticator: senderAuthenticator,
                    secondarySignerAddresses: [],
                    secondaryAuthenticators: [],
                    feePayerAddress: feePayerAddress,
                    feePayerAuthenticator: fpAuth
                ))
            } else {
                transactionAuthenticator = .singleSender(senderAuthenticator)
            }

        case .multiAgent(let multiAgent):
            let secondaryAuths = additionalSignersAuthenticators ?? []

            if let feePayerAddress = multiAgent.feePayerAddress, let fpAuth = feePayerAuthenticator {
                transactionAuthenticator = .feePayer(FeePayerAuthenticator(
                    senderAuthenticator: senderAuthenticator,
                    secondarySignerAddresses: multiAgent.secondarySignerAddresses,
                    secondaryAuthenticators: secondaryAuths,
                    feePayerAddress: feePayerAddress,
                    feePayerAuthenticator: fpAuth
                ))
            } else {
                transactionAuthenticator = .multiAgent(MultiAgentAuthenticator(
                    senderAuthenticator: senderAuthenticator,
                    secondarySignerAddresses: multiAgent.secondarySignerAddresses,
                    secondaryAuthenticators: secondaryAuths
                ))
            }
        }

        return SignedTransaction(rawTransaction: rawTxn, authenticator: transactionAuthenticator)
    }

    /// Build a simulated transaction with empty signatures.
    public static func buildSimulationSignedTransaction(
        transaction: AnyRawTransaction,
        signerPublicKey: AnyPublicKey,
        feePayerPublicKey: AnyPublicKey? = nil
    ) throws -> SignedTransaction {
        let emptySignature = try AnySignature.ed25519(
            Ed25519Signature(data: Data(repeating: 0, count: 64))
        )
        let senderAuth = AccountAuthenticator.singleKey(
            publicKey: signerPublicKey,
            signature: emptySignature
        )

        let feePayerAuth: AccountAuthenticator? = feePayerPublicKey.map { pk in
            .singleKey(publicKey: pk, signature: emptySignature)
        }

        return try buildSignedTransaction(
            transaction: transaction,
            senderAuthenticator: senderAuth,
            feePayerAuthenticator: feePayerAuth
        )
    }
}
