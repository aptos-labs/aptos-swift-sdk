import Foundation

// MARK: - TransactionBuilder

/// Fluent builder for constructing raw transactions.
///
/// Uses an immutable copy-on-write pattern: each setter returns a new builder with the
/// modified field, leaving the original unchanged.
///
/// ```swift
/// let raw = try TransactionBuilder()
///     .sender(account.accountAddress)
///     .sequenceNumber(0)
///     .payload(.entryFunction(entryFunc))
///     .chainId(.testnet)
///     .build()
/// ```
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
    public func sender(_ address: AccountAddress) -> Self {
        var copy = self
        copy.sender = address
        return copy
    }

    /// Sets the sequence number.
    public func sequenceNumber(_ seq: UInt64) -> Self {
        var copy = self
        copy.sequenceNumber = seq
        return copy
    }

    /// Sets the transaction payload.
    public func payload(_ payload: TransactionPayload) -> Self {
        var copy = self
        copy.payload = payload
        return copy
    }

    /// Sets the maximum gas amount.
    public func maxGasAmount(_ amount: UInt64) -> Self {
        var copy = self
        copy.maxGasAmount = amount
        return copy
    }

    /// Sets the gas unit price.
    public func gasUnitPrice(_ price: UInt64) -> Self {
        var copy = self
        copy.gasUnitPrice = price
        return copy
    }

    /// Sets the expiration timestamp.
    public func expirationTimestampSecs(_ timestamp: UInt64) -> Self {
        var copy = self
        copy.expirationTimestampSecs = timestamp
        return copy
    }

    /// Sets the chain ID.
    public func chainId(_ id: ChainId) -> Self {
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

        let expiry = expirationTimestampSecs ?? UInt64(Date().timeIntervalSince1970) + AptosConstants
            .defaultTxnExpirySecs

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

// MARK: - SimpleTransaction

/// A simple (single-signer) transaction wrapper.
///
/// Optionally holds a fee payer address for sponsored transactions. When a fee payer
/// is set, the signing message uses the ``RawTransactionWithData/feePayer`` domain prefix
/// instead of the standard ``RawTransaction`` prefix.
public struct SimpleTransaction: Sendable, Equatable {
    /// The underlying raw transaction.
    public let rawTransaction: RawTransaction

    /// The address of the fee payer, or `nil` for standard (non-sponsored) transactions.
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

// MARK: - MultiAgentTransaction

/// A multi-agent transaction wrapper.
///
/// Multi-agent transactions require signatures from the primary sender plus one or more
/// secondary signers. Optionally includes a fee payer for sponsored execution.
public struct MultiAgentTransaction: Sendable, Equatable {
    /// The underlying raw transaction from the primary sender.
    public let rawTransaction: RawTransaction

    /// Addresses of all secondary signers, in the order they must sign.
    public let secondarySignerAddresses: [AccountAddress]

    /// The address of the fee payer, or `nil` for standard multi-agent transactions.
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

// MARK: - AnyRawTransaction

/// Type-erasing wrapper for any transaction type (simple or multi-agent).
///
/// Used by ``TransactionSigner`` to sign transactions without specializing on the
/// concrete transaction variant.
public enum AnyRawTransaction: Sendable, Equatable {
    case simple(SimpleTransaction)
    case multiAgent(MultiAgentTransaction)

    public var rawTransaction: RawTransaction {
        switch self {
        case let .simple(t): t.rawTransaction
        case let .multiAgent(t): t.rawTransaction
        }
    }

    public func signingMessage() throws -> Data {
        switch self {
        case let .simple(t): try t.signingMessage()
        case let .multiAgent(t): try t.signingMessage()
        }
    }
}
