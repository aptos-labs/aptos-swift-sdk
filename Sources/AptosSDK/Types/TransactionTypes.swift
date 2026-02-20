import Foundation

// MARK: - Transaction Response (Polymorphic)

/// A transaction response from the API (can be pending or committed).
public struct TransactionResponse: Codable, Sendable {
    public let type: String
    public let hash: String
    public let sender: String?
    public let sequenceNumber: String?
    public let maxGasAmount: String?
    public let gasUnitPrice: String?
    public let expirationTimestampSecs: String?
    public let payload: TransactionPayloadResponse?
    public let signature: TransactionSignatureResponse?

    // Present only in committed transactions
    public let version: String?
    public let stateChangeHash: String?
    public let eventRootHash: String?
    public let stateCheckpointHash: String?
    public let gasUsed: String?
    public let success: Bool?
    public let vmStatus: String?
    public let accumulatorRootHash: String?
    public let changes: [WriteSetChange]?
    public let events: [EventResponse]?
    public let timestamp: String?

    public var isPending: Bool { type == "pending_transaction" }
}

/// A committed transaction response with guaranteed non-optional fields.
public struct CommittedTransactionResponse: Codable, Sendable {
    public let type: String
    public let hash: String
    public let sender: String
    public let sequenceNumber: String
    public let maxGasAmount: String
    public let gasUnitPrice: String
    public let expirationTimestampSecs: String
    public let payload: TransactionPayloadResponse?
    public let signature: TransactionSignatureResponse?
    public let version: String
    public let stateChangeHash: String
    public let eventRootHash: String
    public let stateCheckpointHash: String?
    public let gasUsed: String
    public let success: Bool
    public let vmStatus: String
    public let accumulatorRootHash: String
    public let changes: [WriteSetChange]?
    public let events: [EventResponse]?
    public let timestamp: String
}

/// A pending transaction response.
public struct PendingTransactionResponse: Codable, Sendable {
    public let hash: String
    public let sender: String
    public let sequenceNumber: String
    public let maxGasAmount: String
    public let gasUnitPrice: String
    public let expirationTimestampSecs: String
    public let payload: TransactionPayloadResponse?
    public let signature: TransactionSignatureResponse?
}

// MARK: - Transaction Payload Response

/// JSON representation of a transaction payload.
public struct TransactionPayloadResponse: Codable, Sendable {
    public let type: String
    public let function: String?
    public let typeArguments: [String]?
    public let arguments: [AnyCodable]?
    public let code: CodeResponse?
}

/// Bytecode in a script payload.
public struct CodeResponse: Codable, Sendable {
    public let bytecode: String
    public let abi: MoveFunction?
}

// MARK: - Transaction Signature Response

/// JSON representation of a transaction signature.
public struct TransactionSignatureResponse: Codable, Sendable {
    public let type: String
    public let publicKey: AnyCodable?
    public let signature: AnyCodable?
    public let sender: AnyCodable?
    public let secondarySignerAddresses: [String]?
    public let secondarySigners: [AnyCodable]?
    public let feePayerAddress: String?
    public let feePayerSigner: AnyCodable?
}

// MARK: - Write Set Changes

/// A write set change from a committed transaction.
public struct WriteSetChange: Codable, Sendable {
    public let type: String
    public let stateKeyHash: String?
    public let address: String?
    public let module: String?
    public let resource: String?
    public let data: AnyCodable?
    public let handle: String?
    public let key: String?
    public let value: String?
}

// MARK: - Events

/// An event emitted during transaction execution.
public struct EventResponse: Codable, Sendable {
    public let guid: EventGUID
    public let sequenceNumber: String
    public let type: String
    public let data: AnyCodable
}

/// Event GUID structure.
public struct EventGUID: Codable, Sendable {
    public let creationNumber: String
    public let accountAddress: String
}

// MARK: - Simulation Result

/// Result of simulating a transaction.
public typealias SimulateTransactionResponse = [CommittedTransactionResponse]

// MARK: - User Transaction Signature Types

/// Input for simulating a transaction.
public struct SimulateTransactionData: Sendable {
    public let transaction: AnyRawTransaction
    public let signerPublicKey: AnyPublicKey
    public let feePayerPublicKey: AnyPublicKey?

    public init(
        transaction: AnyRawTransaction,
        signerPublicKey: AnyPublicKey,
        feePayerPublicKey: AnyPublicKey? = nil
    ) {
        self.transaction = transaction
        self.signerPublicKey = signerPublicKey
        self.feePayerPublicKey = feePayerPublicKey
    }
}
