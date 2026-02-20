import Foundation

/// A chain identifier.
public struct ChainId: Serializable, Deserializable, Sendable, Hashable {
    public let value: UInt8

    public init(_ value: UInt8) {
        self.value = value
    }

    public func serialize(to serializer: inout Serializer) {
        serializer.serializeU8(value)
    }

    public static func deserialize(from deserializer: inout Deserializer) throws -> ChainId {
        ChainId(try deserializer.deserializeU8())
    }
}

/// A Move module identifier (address::name).
public struct ModuleId: Serializable, Deserializable, Sendable, Hashable {
    public let address: AccountAddress
    public let name: String

    public init(address: AccountAddress, name: String) {
        self.address = address
        self.name = name
    }

    public func serialize(to serializer: inout Serializer) {
        address.serialize(to: &serializer)
        serializer.serializeStr(name)
    }

    public static func deserialize(from deserializer: inout Deserializer) throws -> ModuleId {
        let address = try AccountAddress.deserialize(from: &deserializer)
        let name = try deserializer.deserializeStr()
        return ModuleId(address: address, name: name)
    }
}

/// A raw on-chain transaction before signing.
public struct RawTransaction: Serializable, Deserializable, Sendable, Hashable {
    public let sender: AccountAddress
    public let sequenceNumber: UInt64
    public let payload: TransactionPayload
    public let maxGasAmount: UInt64
    public let gasUnitPrice: UInt64
    public let expirationTimestampSecs: UInt64
    public let chainId: ChainId

    public init(
        sender: AccountAddress,
        sequenceNumber: UInt64,
        payload: TransactionPayload,
        maxGasAmount: UInt64,
        gasUnitPrice: UInt64,
        expirationTimestampSecs: UInt64,
        chainId: ChainId
    ) {
        self.sender = sender
        self.sequenceNumber = sequenceNumber
        self.payload = payload
        self.maxGasAmount = maxGasAmount
        self.gasUnitPrice = gasUnitPrice
        self.expirationTimestampSecs = expirationTimestampSecs
        self.chainId = chainId
    }

    public func serialize(to serializer: inout Serializer) {
        sender.serialize(to: &serializer)
        serializer.serializeU64(sequenceNumber)
        payload.serialize(to: &serializer)
        serializer.serializeU64(maxGasAmount)
        serializer.serializeU64(gasUnitPrice)
        serializer.serializeU64(expirationTimestampSecs)
        chainId.serialize(to: &serializer)
    }

    public static func deserialize(from deserializer: inout Deserializer) throws -> RawTransaction {
        RawTransaction(
            sender: try AccountAddress.deserialize(from: &deserializer),
            sequenceNumber: try deserializer.deserializeU64(),
            payload: try TransactionPayload.deserialize(from: &deserializer),
            maxGasAmount: try deserializer.deserializeU64(),
            gasUnitPrice: try deserializer.deserializeU64(),
            expirationTimestampSecs: try deserializer.deserializeU64(),
            chainId: try ChainId.deserialize(from: &deserializer)
        )
    }
}

/// A simple single-signer transaction.
public struct SimpleTransaction: Sendable {
    public let rawTransaction: RawTransaction
    public var feePayerAddress: AccountAddress?

    public init(rawTransaction: RawTransaction, feePayerAddress: AccountAddress? = nil) {
        self.rawTransaction = rawTransaction
        self.feePayerAddress = feePayerAddress
    }
}

/// A multi-agent transaction with secondary signers.
public struct MultiAgentTransaction: Sendable {
    public let rawTransaction: RawTransaction
    public let secondarySignerAddresses: [AccountAddress]
    public var feePayerAddress: AccountAddress?

    public init(
        rawTransaction: RawTransaction,
        secondarySignerAddresses: [AccountAddress],
        feePayerAddress: AccountAddress? = nil
    ) {
        self.rawTransaction = rawTransaction
        self.secondarySignerAddresses = secondarySignerAddresses
        self.feePayerAddress = feePayerAddress
    }
}

/// Either transaction type.
public enum AnyRawTransaction: Sendable {
    case simple(SimpleTransaction)
    case multiAgent(MultiAgentTransaction)

    /// The underlying raw transaction.
    public var rawTransaction: RawTransaction {
        switch self {
        case .simple(let t): return t.rawTransaction
        case .multiAgent(let t): return t.rawTransaction
        }
    }

    /// Compute the signing message for this transaction.
    ///
    /// The signing message uses the appropriate domain separator:
    /// - Simple (no fee payer): `SHA3-256("APTOS::RawTransaction" || BCS(rawTxn))`
    /// - With fee payer or multi-agent: `SHA3-256("APTOS::RawTransactionWithData" || BCS(...))`
    public func signingMessage() -> Data {
        let rawTxnSalt = sha3_256(Data(rawTransactionSalt.utf8))
        let withDataSalt = sha3_256(Data(rawTransactionWithDataSalt.utf8))

        switch self {
        case .simple(let txn) where txn.feePayerAddress == nil:
            var message = rawTxnSalt
            message.append(txn.rawTransaction.bcsToBytes())
            return sha3_256(message)

        case .simple(let txn):
            // Fee payer variant
            var serializer = Serializer()
            // Variant index 0 = fee payer for SimpleTransaction
            serializer.serializeU32AsUleb128(0)
            txn.rawTransaction.serialize(to: &serializer)
            // secondarySignerAddresses = empty vector
            serializer.serializeU32AsUleb128(0)
            txn.feePayerAddress!.serialize(to: &serializer)
            var message = withDataSalt
            message.append(serializer.output())
            return sha3_256(message)

        case .multiAgent(let txn) where txn.feePayerAddress == nil:
            var serializer = Serializer()
            serializer.serializeU32AsUleb128(0)  // MultiAgent variant
            txn.rawTransaction.serialize(to: &serializer)
            serializer.serializeU32AsUleb128(UInt32(txn.secondarySignerAddresses.count))
            for addr in txn.secondarySignerAddresses {
                addr.serialize(to: &serializer)
            }
            var message = withDataSalt
            message.append(serializer.output())
            return sha3_256(message)

        case .multiAgent(let txn):
            // Multi-agent with fee payer
            var serializer = Serializer()
            serializer.serializeU32AsUleb128(0)
            txn.rawTransaction.serialize(to: &serializer)
            serializer.serializeU32AsUleb128(UInt32(txn.secondarySignerAddresses.count))
            for addr in txn.secondarySignerAddresses {
                addr.serialize(to: &serializer)
            }
            txn.feePayerAddress!.serialize(to: &serializer)
            var message = withDataSalt
            message.append(serializer.output())
            return sha3_256(message)
        }
    }
}

/// Options for generating a transaction.
public struct TransactionOptions: Sendable {
    public var maxGasAmount: UInt64?
    public var gasUnitPrice: UInt64?
    public var expireTimestamp: UInt64?
    public var accountSequenceNumber: UInt64?
    public var replayProtectionNonce: UInt64?

    public init(
        maxGasAmount: UInt64? = nil,
        gasUnitPrice: UInt64? = nil,
        expireTimestamp: UInt64? = nil,
        accountSequenceNumber: UInt64? = nil,
        replayProtectionNonce: UInt64? = nil
    ) {
        self.maxGasAmount = maxGasAmount
        self.gasUnitPrice = gasUnitPrice
        self.expireTimestamp = expireTimestamp
        self.accountSequenceNumber = accountSequenceNumber
        self.replayProtectionNonce = replayProtectionNonce
    }
}

/// A signed transaction ready for submission.
public struct SignedTransaction: Serializable, Sendable {
    public let rawTransaction: RawTransaction
    public let authenticator: TransactionAuthenticator

    public init(rawTransaction: RawTransaction, authenticator: TransactionAuthenticator) {
        self.rawTransaction = rawTransaction
        self.authenticator = authenticator
    }

    public func serialize(to serializer: inout Serializer) {
        rawTransaction.serialize(to: &serializer)
        authenticator.serialize(to: &serializer)
    }
}
