import Foundation

// MARK: - LedgerInfo

/// Ledger information from the full node.
public struct LedgerInfo: Codable, Sendable {
    public let chainId: UInt8
    public let epoch: String
    public let ledgerVersion: String
    public let oldestLedgerVersion: String
    public let ledgerTimestamp: String
    public let nodeRole: String?
    public let oldestBlockHeight: String?
    public let blockHeight: String?
    public let gitHash: String?

    enum CodingKeys: String, CodingKey {
        case chainId = "chain_id"
        case epoch
        case ledgerVersion = "ledger_version"
        case oldestLedgerVersion = "oldest_ledger_version"
        case ledgerTimestamp = "ledger_timestamp"
        case nodeRole = "node_role"
        case oldestBlockHeight = "oldest_block_height"
        case blockHeight = "block_height"
        case gitHash = "git_hash"
    }
}

// MARK: - AccountData

/// Account data from the full node.
public struct AccountData: Codable, Sendable {
    public let sequenceNumber: String
    public let authenticationKey: String

    enum CodingKeys: String, CodingKey {
        case sequenceNumber = "sequence_number"
        case authenticationKey = "authentication_key"
    }
}

// MARK: - AccountResource

/// An account resource.
public struct AccountResource: Codable, Sendable {
    public let type: String
    public let data: AnyCodable
}

// MARK: - MoveModule

/// A Move module.
public struct MoveModule: Codable, Sendable {
    public let bytecode: String
    public let abi: MoveModuleABI?
}

// MARK: - MoveModuleABI

/// Move module ABI.
public struct MoveModuleABI: Codable, Sendable {
    public let address: String
    public let name: String
    public let friends: [String]?
    public let exposedFunctions: [MoveFunctionABI]?
    public let structs: [MoveStructABI]?

    enum CodingKeys: String, CodingKey {
        case address, name, friends
        case exposedFunctions = "exposed_functions"
        case structs
    }
}

// MARK: - MoveFunctionABI

/// Move function ABI.
public struct MoveFunctionABI: Codable, Sendable {
    public let name: String
    public let visibility: String
    public let isEntry: Bool
    public let isView: Bool
    public let genericTypeParams: [GenericTypeParam]?
    public let params: [String]
    public let returnValues: [String]?

    enum CodingKeys: String, CodingKey {
        case name, visibility
        case isEntry = "is_entry"
        case isView = "is_view"
        case genericTypeParams = "generic_type_params"
        case params
        case returnValues = "return"
    }
}

// MARK: - GenericTypeParam

/// Generic type parameter constraint.
public struct GenericTypeParam: Codable, Sendable {
    public let constraints: [String]
}

// MARK: - MoveStructABI

/// Move struct ABI.
public struct MoveStructABI: Codable, Sendable {
    public let name: String
    public let isNative: Bool
    public let abilities: [String]
    public let genericTypeParams: [GenericTypeParam]?
    public let fields: [MoveStructField]?

    enum CodingKeys: String, CodingKey {
        case name
        case isNative = "is_native"
        case abilities
        case genericTypeParams = "generic_type_params"
        case fields
    }
}

// MARK: - MoveStructField

/// Move struct field.
public struct MoveStructField: Codable, Sendable {
    public let name: String
    public let type: String
}

// MARK: - GasEstimate

/// Gas estimation result.
public struct GasEstimate: Codable, Sendable {
    public let gasEstimate: UInt64
    public let deprioritizedGasEstimate: UInt64?
    public let prioritizedGasEstimate: UInt64?

    enum CodingKeys: String, CodingKey {
        case gasEstimate = "gas_estimate"
        case deprioritizedGasEstimate = "deprioritized_gas_estimate"
        case prioritizedGasEstimate = "prioritized_gas_estimate"
    }
}

// MARK: - Block

/// Block information.
public struct Block: Codable, Sendable {
    public let blockHeight: String
    public let blockHash: String
    public let blockTimestamp: String
    public let firstVersion: String
    public let lastVersion: String
    public let transactions: [TransactionResponse]?

    enum CodingKeys: String, CodingKey {
        case blockHeight = "block_height"
        case blockHash = "block_hash"
        case blockTimestamp = "block_timestamp"
        case firstVersion = "first_version"
        case lastVersion = "last_version"
        case transactions
    }
}

// MARK: - PendingTransactionResponse

/// Pending transaction response from submission.
public struct PendingTransactionResponse: Codable, Sendable {
    public let hash: String
    public let sender: String
    public let sequenceNumber: String
    public let maxGasAmount: String
    public let gasUnitPrice: String
    public let expirationTimestampSecs: String
    public let payload: AnyCodable

    enum CodingKeys: String, CodingKey {
        case hash, sender
        case sequenceNumber = "sequence_number"
        case maxGasAmount = "max_gas_amount"
        case gasUnitPrice = "gas_unit_price"
        case expirationTimestampSecs = "expiration_timestamp_secs"
        case payload
    }
}

// MARK: - TransactionResponse

/// Transaction response (committed or pending).
public struct TransactionResponse: Codable, Sendable {
    public let type: String?
    public let version: String?
    public let hash: String
    public let stateChangeHash: String?
    public let eventRootHash: String?
    public let stateCheckpointHash: String?
    public let gasUsed: String?
    public let success: Bool?
    public let vmStatus: String?
    public let accumulatorRootHash: String?
    public let sender: String?
    public let sequenceNumber: String?
    public let maxGasAmount: String?
    public let gasUnitPrice: String?
    public let expirationTimestampSecs: String?
    public let payload: AnyCodable?
    public let events: [EventResponse]?
    public let timestamp: String?

    enum CodingKeys: String, CodingKey {
        case type, version, hash
        case stateChangeHash = "state_change_hash"
        case eventRootHash = "event_root_hash"
        case stateCheckpointHash = "state_checkpoint_hash"
        case gasUsed = "gas_used"
        case success
        case vmStatus = "vm_status"
        case accumulatorRootHash = "accumulator_root_hash"
        case sender
        case sequenceNumber = "sequence_number"
        case maxGasAmount = "max_gas_amount"
        case gasUnitPrice = "gas_unit_price"
        case expirationTimestampSecs = "expiration_timestamp_secs"
        case payload, events, timestamp
    }

    /// Whether this is a pending transaction.
    public var isPending: Bool {
        type == "pending_transaction"
    }
}

// MARK: - EventResponse

/// Event response.
public struct EventResponse: Codable, Sendable {
    public let guid: EventGuid?
    public let sequenceNumber: String?
    public let type: String
    public let data: AnyCodable

    enum CodingKeys: String, CodingKey {
        case guid
        case sequenceNumber = "sequence_number"
        case type, data
    }
}

// MARK: - EventGuid

/// Event GUID.
public struct EventGuid: Codable, Sendable {
    public let creationNumber: String
    public let accountAddress: String

    enum CodingKeys: String, CodingKey {
        case creationNumber = "creation_number"
        case accountAddress = "account_address"
    }
}

// MARK: - FaucetResponse

/// Faucet fund response.
public struct FaucetResponse: Codable, Sendable {
    public let txnHashes: [String]?
    public let message: String?

    enum CodingKeys: String, CodingKey {
        case txnHashes = "txn_hashes"
        case message
    }
}

// MARK: - ViewRequest

/// View function request body.
public struct ViewRequest: Codable, Sendable {
    public let function: String
    public let typeArguments: [String]
    public let arguments: [AnyCodable]

    enum CodingKeys: String, CodingKey {
        case function
        case typeArguments = "type_arguments"
        case arguments
    }
}

// MARK: - AnyCodable

/// Type-erased Codable wrapper for JSON values.
public struct AnyCodable: Codable, @unchecked Sendable, Equatable {
    public let value: Any

    public init(_ value: Any) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([Self].self) {
            value = array.map(\.value)
        } else if let dict = try? container.decode([String: Self].self) {
            value = dict.mapValues(\.value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unable to decode value")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { Self($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { Self($0) })
        default:
            try container.encodeNil()
        }
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        // Simple equality based on string representation
        "\(lhs.value)" == "\(rhs.value)"
    }
}
