import Foundation

/// Transaction building, signing, submission, and querying API.
public struct TransactionAPI: Sendable {
    private let config: AptosConfig
    private let client: AptosHTTPClient
    public let build: TransactionBuilder

    public init(config: AptosConfig, client: AptosHTTPClient) {
        self.config = config
        self.client = client
        self.build = TransactionBuilder(config: config, client: client)
    }

    // MARK: - Signing

    /// Sign a transaction with a single signer.
    public func sign(
        signer: any AptosAccount,
        transaction: AnyRawTransaction
    ) throws -> AccountAuthenticator {
        try TransactionSigner.sign(signer: signer, transaction: transaction)
    }

    // MARK: - Submission

    /// Submit a signed simple transaction.
    public func submit(
        transaction: AnyRawTransaction,
        senderAuthenticator: AccountAuthenticator,
        feePayerAuthenticator: AccountAuthenticator? = nil,
        additionalSignersAuthenticators: [AccountAuthenticator]? = nil
    ) async throws -> PendingTransactionResponse {
        let signedTxn = try TransactionSigner.buildSignedTransaction(
            transaction: transaction,
            senderAuthenticator: senderAuthenticator,
            feePayerAuthenticator: feePayerAuthenticator,
            additionalSignersAuthenticators: additionalSignersAuthenticators
        )
        let bcsData = signedTxn.bcsToBytes()
        let response: AptosResponse<PendingTransactionResponse> = try await client.postBCS(
            path: "/transactions",
            body: bcsData,
            contentType: .bcsSignedTransaction,
            originMethod: "TransactionAPI.submit"
        )
        return response.data
    }

    // MARK: - Simulation

    /// Simulate a transaction without submitting it.
    public func simulate(
        transaction: AnyRawTransaction,
        signerPublicKey: AnyPublicKey,
        feePayerPublicKey: AnyPublicKey? = nil
    ) async throws -> [CommittedTransactionResponse] {
        let signedTxn = try TransactionSigner.buildSimulationSignedTransaction(
            transaction: transaction,
            signerPublicKey: signerPublicKey,
            feePayerPublicKey: feePayerPublicKey
        )
        let bcsData = signedTxn.bcsToBytes()
        let response: AptosResponse<[CommittedTransactionResponse]> = try await client.postBCS(
            path: "/transactions/simulate",
            body: bcsData,
            contentType: .bcsSignedTransaction,
            originMethod: "TransactionAPI.simulate"
        )
        return response.data
    }

    // MARK: - Querying

    /// Get a transaction by hash.
    public func getTransactionByHash(_ hash: String) async throws -> TransactionResponse {
        let response: AptosResponse<TransactionResponse> = try await client.get(
            path: "/transactions/by_hash/\(hash)",
            originMethod: "TransactionAPI.getTransactionByHash"
        )
        return response.data
    }

    /// Get a transaction by version.
    public func getTransactionByVersion(_ version: String) async throws -> TransactionResponse {
        let response: AptosResponse<TransactionResponse> = try await client.get(
            path: "/transactions/by_version/\(version)",
            originMethod: "TransactionAPI.getTransactionByVersion"
        )
        return response.data
    }

    /// Get recent transactions.
    public func getTransactions(
        options: PaginationOptions? = nil
    ) async throws -> [TransactionResponse] {
        let params = options?.queryParams ?? [:]
        let response: AptosResponse<[TransactionResponse]> = try await client.get(
            path: "/transactions",
            params: params.isEmpty ? nil : params,
            originMethod: "TransactionAPI.getTransactions"
        )
        return response.data
    }

    // MARK: - Wait for Transaction

    /// Wait for a transaction to be committed on-chain.
    public func waitForTransaction(
        hash: String,
        options: WaitForTransactionOptions? = nil
    ) async throws -> CommittedTransactionResponse {
        let opts = options ?? WaitForTransactionOptions()
        let timeoutSecs = opts.timeoutSecs
        let deadline = Date().addingTimeInterval(TimeInterval(timeoutSecs))

        var lastError: Error?
        var backoffMs: UInt64 = 200

        while Date() < deadline {
            do {
                let txn = try await getTransactionByHash(hash)

                if !txn.isPending {
                    // Decode as committed
                    let response: AptosResponse<CommittedTransactionResponse> = try await client.get(
                        path: "/transactions/by_hash/\(hash)",
                        originMethod: "TransactionAPI.waitForTransaction"
                    )
                    let committed = response.data

                    if opts.checkSuccess && !committed.success {
                        throw FailedTransactionError(transaction: committed)
                    }
                    return committed
                }
            } catch let error as AptosAPIError where error.status == 404 {
                // Transaction not found yet, keep waiting
                lastError = error
            } catch let error as FailedTransactionError {
                throw error
            } catch {
                lastError = error
            }

            // Exponential backoff
            try await Task.sleep(nanoseconds: backoffMs * 1_000_000)
            backoffMs = min(backoffMs * 2, 5000)
        }

        throw WaitForTransactionError(
            message: "Transaction \(hash) timed out after \(timeoutSecs)s",
            lastSubmittedTransaction: nil
        )
    }

    // MARK: - Convenience

    /// Sign and submit a transaction in one call.
    public func signAndSubmitTransaction(
        signer: any AptosAccount,
        transaction: AnyRawTransaction,
        feePayer: (any AptosAccount)? = nil,
        additionalSigners: [any AptosAccount]? = nil
    ) async throws -> PendingTransactionResponse {
        let senderAuth = try sign(signer: signer, transaction: transaction)
        let feePayerAuth = try feePayer?.signTransactionWithAuthenticator(transaction)
        let additionalAuth = try additionalSigners?.map { try $0.signTransactionWithAuthenticator(transaction) }

        return try await submit(
            transaction: transaction,
            senderAuthenticator: senderAuth,
            feePayerAuthenticator: feePayerAuth,
            additionalSignersAuthenticators: additionalAuth
        )
    }
}
