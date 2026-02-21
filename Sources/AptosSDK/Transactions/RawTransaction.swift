import Foundation

// MARK: - RawTransaction

/// A raw (unsigned) transaction ready for signing.
public struct RawTransaction: Sendable, Equatable {
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

    /// Computes the signing message for this transaction.
    ///
    /// Returns `SHA3-256("APTOS::RawTransaction") || BCS(self)`.
    public func signingMessage() throws -> Data {
        let prefix = AptosHashing.signingPrefix(AptosDomain.rawTransaction)
        let bcs = try bcsToBytes(self)
        return prefix + bcs
    }
}

// MARK: BCSSerializable, BCSDeserializable

extension RawTransaction: BCSSerializable, BCSDeserializable {
    public func serialize(to serializer: inout Serializer) throws {
        try sender.serialize(to: &serializer)
        serializer.serializeU64(sequenceNumber)
        try payload.serialize(to: &serializer)
        serializer.serializeU64(maxGasAmount)
        serializer.serializeU64(gasUnitPrice)
        serializer.serializeU64(expirationTimestampSecs)
        try chainId.serialize(to: &serializer)
    }

    public static func deserialize(from deserializer: inout Deserializer) throws -> RawTransaction {
        let sender = try AccountAddress.deserialize(from: &deserializer)
        let seqNum = try deserializer.deserializeU64()
        let payload = try TransactionPayload.deserialize(from: &deserializer)
        let maxGas = try deserializer.deserializeU64()
        let gasPrice = try deserializer.deserializeU64()
        let expiry = try deserializer.deserializeU64()
        let chainId = try ChainId.deserialize(from: &deserializer)
        return RawTransaction(
            sender: sender, sequenceNumber: seqNum, payload: payload,
            maxGasAmount: maxGas, gasUnitPrice: gasPrice,
            expirationTimestampSecs: expiry, chainId: chainId
        )
    }
}

// MARK: - ChainId

/// Chain identifier (single byte).
public struct ChainId: Sendable, Equatable, Hashable {
    public let value: UInt8

    public init(_ value: UInt8) {
        self.value = value
    }

    public static let mainnet = Self(1)
    public static let testnet = Self(2)
    public static let devnet = Self(3)
    public static let local = Self(4)
}

// MARK: BCSSerializable, BCSDeserializable

extension ChainId: BCSSerializable, BCSDeserializable {
    public func serialize(to serializer: inout Serializer) throws {
        serializer.serializeU8(value)
    }

    public static func deserialize(from deserializer: inout Deserializer) throws -> ChainId {
        ChainId(try deserializer.deserializeU8())
    }
}

// MARK: - SignedTransaction

/// A signed transaction ready for submission.
public struct SignedTransaction: Sendable, Equatable {
    public let rawTransaction: RawTransaction
    public let authenticator: TransactionAuthenticator

    public init(rawTransaction: RawTransaction, authenticator: TransactionAuthenticator) {
        self.rawTransaction = rawTransaction
        self.authenticator = authenticator
    }

    /// Serializes to BCS bytes for submission.
    public func toBytes() throws -> Data {
        try bcsToBytes(self)
    }

    /// Computes the transaction hash.
    public func hash() throws -> Data {
        let prefix = AptosHashing.signingPrefix("APTOS::Transaction")
        // Transaction enum variant 0 = UserTransaction
        var serializer = Serializer()
        try serializer.serializeU32AsUleb128(0)
        try serialize(to: &serializer)
        let bcs = serializer.toBytes()
        return AptosHashing.sha3_256(prefix + bcs)
    }
}

// MARK: BCSSerializable, BCSDeserializable

extension SignedTransaction: BCSSerializable, BCSDeserializable {
    public func serialize(to serializer: inout Serializer) throws {
        try rawTransaction.serialize(to: &serializer)
        try authenticator.serialize(to: &serializer)
    }

    public static func deserialize(from deserializer: inout Deserializer) throws -> SignedTransaction {
        let raw = try RawTransaction.deserialize(from: &deserializer)
        let auth = try TransactionAuthenticator.deserialize(from: &deserializer)
        return SignedTransaction(rawTransaction: raw, authenticator: auth)
    }
}

// MARK: - RawTransactionWithData

/// Extended raw transaction used for multi-agent and fee-payer signing messages.
public enum RawTransactionWithData: Sendable, Equatable {
    /// Multi-agent variant (index 0).
    case multiAgent(rawTransaction: RawTransaction, secondarySignerAddresses: [AccountAddress])
    /// Fee payer variant (index 1).
    case feePayer(
        rawTransaction: RawTransaction,
        secondarySignerAddresses: [AccountAddress],
        feePayerAddress: AccountAddress
    )

    /// Computes the signing message for multi-agent/fee-payer transactions.
    public func signingMessage() throws -> Data {
        let prefix = AptosHashing.signingPrefix(AptosDomain.rawTransactionWithData)
        let bcs = try bcsToBytes(self)
        return prefix + bcs
    }
}

// MARK: BCSSerializable, BCSDeserializable

extension RawTransactionWithData: BCSSerializable, BCSDeserializable {
    public func serialize(to serializer: inout Serializer) throws {
        switch self {
        case let .multiAgent(rawTxn, addrs):
            try serializer.serializeU32AsUleb128(0)
            try rawTxn.serialize(to: &serializer)
            try serializer.serializeVector(addrs)
        case let .feePayer(rawTxn, addrs, feeAddr):
            try serializer.serializeU32AsUleb128(1)
            try rawTxn.serialize(to: &serializer)
            try serializer.serializeVector(addrs)
            try feeAddr.serialize(to: &serializer)
        }
    }

    public static func deserialize(from deserializer: inout Deserializer) throws -> RawTransactionWithData {
        let variant = try deserializer.deserializeUleb128()
        switch variant {
        case 0:
            let raw = try RawTransaction.deserialize(from: &deserializer)
            let addrs = try deserializer.deserializeVector(AccountAddress.self)
            return .multiAgent(rawTransaction: raw, secondarySignerAddresses: addrs)
        case 1:
            let raw = try RawTransaction.deserialize(from: &deserializer)
            let addrs = try deserializer.deserializeVector(AccountAddress.self)
            let feeAddr = try AccountAddress.deserialize(from: &deserializer)
            return .feePayer(rawTransaction: raw, secondarySignerAddresses: addrs, feePayerAddress: feeAddr)
        default:
            throw AptosError.serialization(.invalidData(
                "Unknown RawTransactionWithData variant: \(variant)"
            ))
        }
    }
}
