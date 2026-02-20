import Foundation

// MARK: - TransactionAPI

/// Transaction building, signing, submission, and querying.
public struct TransactionAPI: Sendable {
    private let config: AptosConfig
    private let client: AptosHTTPClient

    init(config: AptosConfig, client: AptosHTTPClient) {
        self.config = config
        self.client = client
    }

    // MARK: - Build

    /// Builds a simple (single-signer) transaction.
    public func buildSimple(
        sender: AccountAddress,
        payload: TransactionPayload,
        options: TransactionOptions = TransactionOptions()
    ) async throws -> SimpleTransaction {
        let url = try config.getFullnodeURL()

        // Fetch sequence number if not provided
        let seqNum: UInt64
        if let provided = options.sequenceNumber {
            seqNum = provided
        } else {
            let accountData: AccountData = try await client.get(
                url: url, path: "accounts/\(sender.toHex())"
            )
            seqNum = UInt64(accountData.sequenceNumber) ?? 0
        }

        // Fetch gas price if not provided
        let gasPrice: UInt64
        if let provided = options.gasUnitPrice {
            gasPrice = provided
        } else {
            let estimate: GasEstimate = try await client.get(url: url, path: "estimate_gas_price")
            gasPrice = estimate.gasEstimate
        }

        // Fetch chain ID
        let chainId: ChainId
        if let provided = options.chainId {
            chainId = provided
        } else if let preset = config.network.chainId {
            chainId = preset
        } else {
            let info: LedgerInfo = try await client.get(url: url)
            chainId = ChainId(info.chainId)
        }

        let maxGas = options.maxGasAmount ?? config.transactionConfig.defaultMaxGasAmount
        let expiry = options.expirationTimestampSecs ?? (
            UInt64(Date().timeIntervalSince1970) + config.transactionConfig.defaultTxnExpirySecs
        )

        let rawTxn = RawTransaction(
            sender: sender,
            sequenceNumber: seqNum,
            payload: payload,
            maxGasAmount: maxGas,
            gasUnitPrice: gasPrice,
            expirationTimestampSecs: expiry,
            chainId: chainId
        )

        return SimpleTransaction(rawTransaction: rawTxn, feePayerAddress: options.feePayerAddress)
    }

    // MARK: - Sign

    /// Signs a transaction with the given account.
    public func sign(
        signer: any AptosAccount,
        transaction: AnyRawTransaction
    ) throws -> AccountAuthenticator {
        try TransactionSigner.sign(transaction: transaction, signer: signer)
    }

    // MARK: - Submit

    /// Submits a signed transaction to the blockchain.
    public func submit(signedTransaction: SignedTransaction) async throws -> PendingTransactionResponse {
        let url = try config.getFullnodeURL()
        let bcsBytes = try signedTransaction.toBytes()
        return try await client.postBCS(url: url, path: "transactions", body: bcsBytes)
    }

    /// Signs and submits a simple transaction.
    public func signAndSubmit(
        signer: any AptosAccount,
        transaction: SimpleTransaction
    ) async throws -> PendingTransactionResponse {
        let auth = try TransactionSigner.sign(
            transaction: .simple(transaction), signer: signer
        )
        let signed = try TransactionSigner.createSignedTransaction(
            transaction: transaction, senderAuthenticator: auth
        )
        return try await submit(signedTransaction: signed)
    }

    // MARK: - Wait

    /// Waits for a transaction to be confirmed on-chain.
    public func waitForTransaction(
        hash: String,
        timeoutSecs: UInt64 = AptosConstants.defaultTxnTimeoutSecs,
        checkSuccess: Bool = true
    ) async throws -> TransactionResponse {
        let url = try config.getFullnodeURL()
        let startTime = Date()
        let timeout = TimeInterval(timeoutSecs)
        var backoff: TimeInterval = 0.2

        while Date().timeIntervalSince(startTime) < timeout {
            do {
                let txn: TransactionResponse = try await client.get(
                    url: url, path: "transactions/by_hash/\(hash)"
                )

                if !txn.isPending {
                    if checkSuccess, txn.success == false {
                        throw AptosError.transaction(.executionFailed(
                            hash: hash,
                            message: txn.vmStatus ?? "Unknown error"
                        ))
                    }
                    return txn
                }
            } catch let error as AptosError {
                if case let .network(.httpError(code, _)) = error {
                    if code == 404 || code >= 500 {
                        // Retryable
                    } else {
                        throw error
                    }
                } else if case .transaction = error {
                    throw error
                }
            }

            try await Task.sleep(nanoseconds: UInt64(backoff * 1_000_000_000))
            backoff = min(backoff * 1.5, 5.0)
        }

        throw AptosError.timeout("Transaction \(hash) not confirmed within \(timeoutSecs) seconds")
    }

    /// Builds, signs, submits, and waits for a simple transaction.
    public func submitAndWait(
        sender: any AptosAccount,
        payload: TransactionPayload,
        options: TransactionOptions = TransactionOptions()
    ) async throws -> TransactionResponse {
        let txn = try await buildSimple(
            sender: sender.accountAddress, payload: payload, options: options
        )
        let pending = try await signAndSubmit(signer: sender, transaction: txn)
        return try await waitForTransaction(hash: pending.hash)
    }

    // MARK: - Query

    /// Gets a transaction by its hash.
    public func getTransactionByHash(_ hash: String) async throws -> TransactionResponse {
        let url = try config.getFullnodeURL()
        return try await client.get(url: url, path: "transactions/by_hash/\(hash)")
    }

    /// Gets a transaction by its version.
    public func getTransactionByVersion(_ version: UInt64) async throws -> TransactionResponse {
        let url = try config.getFullnodeURL()
        return try await client.get(url: url, path: "transactions/by_version/\(version)")
    }

    /// Gets transactions for an account.
    public func getAccountTransactions(
        _ address: AccountAddress,
        start: UInt64? = nil,
        limit: Int? = nil
    ) async throws -> [TransactionResponse] {
        let url = try config.getFullnodeURL()
        var params: [String: String] = [:]
        if let start { params["start"] = String(start) }
        if let limit { params["limit"] = String(limit) }
        return try await client.get(
            url: url, path: "accounts/\(address.toHex())/transactions", params: params
        )
    }

    // MARK: - Simulate

    /// Simulates a transaction without actually submitting it.
    public func simulate(
        transaction: AnyRawTransaction,
        signerPublicKey _: (any BCSSerializable)? = nil
    ) async throws -> [TransactionResponse] {
        let url = try config.getFullnodeURL()

        let rawTxn = transaction.rawTransaction
        // Create a simulation signed transaction with empty authenticator
        let auth = TransactionAuthenticator.singleSender(.noAccountAuthenticator)
        let signedTxn = SignedTransaction(rawTransaction: rawTxn, authenticator: auth)
        let bcsBytes = try signedTxn.toBytes()

        return try await client.postBCS(
            url: url, path: "transactions/simulate", body: bcsBytes
        )
    }
}

// MARK: - TransactionOptions

/// Options for transaction building.
public struct TransactionOptions: Sendable {
    public let maxGasAmount: UInt64?
    public let gasUnitPrice: UInt64?
    public let expirationTimestampSecs: UInt64?
    public let sequenceNumber: UInt64?
    public let chainId: ChainId?
    public let feePayerAddress: AccountAddress?

    public init(
        maxGasAmount: UInt64? = nil,
        gasUnitPrice: UInt64? = nil,
        expirationTimestampSecs: UInt64? = nil,
        sequenceNumber: UInt64? = nil,
        chainId: ChainId? = nil,
        feePayerAddress: AccountAddress? = nil
    ) {
        self.maxGasAmount = maxGasAmount
        self.gasUnitPrice = gasUnitPrice
        self.expirationTimestampSecs = expirationTimestampSecs
        self.sequenceNumber = sequenceNumber
        self.chainId = chainId
        self.feePayerAddress = feePayerAddress
    }
}
