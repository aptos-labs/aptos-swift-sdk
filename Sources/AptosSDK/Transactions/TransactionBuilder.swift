import Foundation

/// Fluent builder for constructing raw transactions.
public struct TransactionBuilder: Sendable {
    private var sender: AccountAddress?
    private var sequenceNumber: UInt64?
    private var payload: TransactionPayload?
    private var maxGasAmount: UInt64 = AptosConstants.defaultMaxGasAmount
    private var gasUnitPrice: UInt64 = AptosConstants.defaultGasUnitPrice
    private var expirationTimestampSecs: UInt64?
    private var chainId: ChainId?

    public init() {}

    /// Sets the sender address.
    public func sender(_ address: AccountAddress) -> TransactionBuilder {
        var copy = self
        copy.sender = address
        return copy
    }

    /// Sets the sequence number.
    public func sequenceNumber(_ seq: UInt64) -> TransactionBuilder {
        var copy = self
        copy.sequenceNumber = seq
        return copy
    }

    /// Sets the transaction payload.
    public func payload(_ payload: TransactionPayload) -> TransactionBuilder {
        var copy = self
        copy.payload = payload
        return copy
    }

    /// Sets the maximum gas amount.
    public func maxGasAmount(_ amount: UInt64) -> TransactionBuilder {
        var copy = self
        copy.maxGasAmount = amount
        return copy
    }

    /// Sets the gas unit price.
    public func gasUnitPrice(_ price: UInt64) -> TransactionBuilder {
        var copy = self
        copy.gasUnitPrice = price
        return copy
    }

    /// Sets the expiration timestamp.
    public func expirationTimestampSecs(_ timestamp: UInt64) -> TransactionBuilder {
        var copy = self
        copy.expirationTimestampSecs = timestamp
        return copy
    }

    /// Sets the chain ID.
    public func chainId(_ id: ChainId) -> TransactionBuilder {
        var copy = self
        copy.chainId = id
        return copy
    }

    /// Builds the raw transaction, validating all required fields.
    public func build() throws -> RawTransaction {
        guard let sender else {
            throw AptosError.transaction(.buildFailed("sender is required"))
        }
        guard let sequenceNumber else {
            throw AptosError.transaction(.buildFailed("sequenceNumber is required"))
        }
        guard let payload else {
            throw AptosError.transaction(.buildFailed("payload is required"))
        }
        guard let chainId else {
            throw AptosError.transaction(.buildFailed("chainId is required"))
        }

        let expiry = expirationTimestampSecs ?? UInt64(Date().timeIntervalSince1970) + AptosConstants.defaultTxnExpirySecs

        return RawTransaction(
            sender: sender,
            sequenceNumber: sequenceNumber,
            payload: payload,
            maxGasAmount: maxGasAmount,
            gasUnitPrice: gasUnitPrice,
            expirationTimestampSecs: expiry,
            chainId: chainId
        )
    }
}

// MARK: - Transaction Types

/// A simple (single-signer) transaction wrapper.
public struct SimpleTransaction: Sendable, Equatable {
    public let rawTransaction: RawTransaction
    public let feePayerAddress: AccountAddress?

    public init(rawTransaction: RawTransaction, feePayerAddress: AccountAddress? = nil) {
        self.rawTransaction = rawTransaction
        self.feePayerAddress = feePayerAddress
    }

    /// Computes the signing message for this transaction.
    public func signingMessage() throws -> Data {
        if let feePayer = feePayerAddress {
            let withData = RawTransactionWithData.feePayer(
                rawTransaction: rawTransaction,
                secondarySignerAddresses: [],
                feePayerAddress: feePayer
            )
            return try withData.signingMessage()
        }
        return try rawTransaction.signingMessage()
    }
}

/// A multi-agent transaction wrapper.
public struct MultiAgentTransaction: Sendable, Equatable {
    public let rawTransaction: RawTransaction
    public let secondarySignerAddresses: [AccountAddress]
    public let feePayerAddress: AccountAddress?

    public init(
        rawTransaction: RawTransaction,
        secondarySignerAddresses: [AccountAddress],
        feePayerAddress: AccountAddress? = nil
    ) {
        self.rawTransaction = rawTransaction
        self.secondarySignerAddresses = secondarySignerAddresses
        self.feePayerAddress = feePayerAddress
    }

    /// Computes the signing message for all signers.
    public func signingMessage() throws -> Data {
        if let feePayer = feePayerAddress {
            let withData = RawTransactionWithData.feePayer(
                rawTransaction: rawTransaction,
                secondarySignerAddresses: secondarySignerAddresses,
                feePayerAddress: feePayer
            )
            return try withData.signingMessage()
        }
        let withData = RawTransactionWithData.multiAgent(
            rawTransaction: rawTransaction,
            secondarySignerAddresses: secondarySignerAddresses
        )
        return try withData.signingMessage()
    }
}

/// Type-erasing wrapper for any transaction type.
public enum AnyRawTransaction: Sendable, Equatable {
    case simple(SimpleTransaction)
    case multiAgent(MultiAgentTransaction)

    public var rawTransaction: RawTransaction {
        switch self {
        case .simple(let t): return t.rawTransaction
        case .multiAgent(let t): return t.rawTransaction
        }
    }

    public func signingMessage() throws -> Data {
        switch self {
        case .simple(let t): return try t.signingMessage()
        case .multiAgent(let t): return try t.signingMessage()
        }
    }
}
