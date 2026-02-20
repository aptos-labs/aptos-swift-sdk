import Foundation

// MARK: - Ledger Info

/// Ledger state returned by GET /v1.
public struct LedgerInfo: Codable, Sendable {
    public let chainId: UInt8
    public let epoch: String
    public let ledgerVersion: String
    public let oldestLedgerVersion: String
    public let ledgerTimestamp: String
    public let nodeRole: String
    public let oldestBlockHeight: String
    public let blockHeight: String
    public let gitHash: String
}

// MARK: - Account Data

/// Account info returned by GET /accounts/{address}.
public struct AccountData: Codable, Sendable {
    public let sequenceNumber: String
    public let authenticationKey: String
}

// MARK: - Account Resource

/// An on-chain resource.
public struct AccountResource: Codable, Sendable {
    public let type: String
    public let data: AnyCodable
}

// MARK: - Move Module

/// A Move module with its bytecode and ABI.
public struct MoveModuleBytecode: Codable, Sendable {
    public let bytecode: String
    public let abi: MoveModule?
}

/// A Move module ABI description.
public struct MoveModule: Codable, Sendable {
    public let address: String
    public let name: String
    public let friends: [MoveModuleId]
    public let exposedFunctions: [MoveFunction]
    public let structs: [MoveStruct]
}

/// A Move module identifier (address::module).
public struct MoveModuleId: Codable, Sendable {
    public let address: String
    public let name: String
}

/// A Move function ABI.
public struct MoveFunction: Codable, Sendable {
    public let name: String
    public let visibility: String
    public let isEntry: Bool
    public let isView: Bool
    public let genericTypeParams: [MoveFunctionGenericTypeParam]
    public let params: [String]
    public let `return`: [String]
}

/// Generic type parameter for a Move function.
public struct MoveFunctionGenericTypeParam: Codable, Sendable {
    public let constraints: [String]
}

/// A Move struct ABI.
public struct MoveStruct: Codable, Sendable {
    public let name: String
    public let isNative: Bool
    public let abilities: [String]
    public let genericTypeParams: [MoveStructGenericTypeParam]
    public let fields: [MoveStructField]
}

/// Generic type parameter for a Move struct.
public struct MoveStructGenericTypeParam: Codable, Sendable {
    public let constraints: [String]
}

/// A field in a Move struct.
public struct MoveStructField: Codable, Sendable {
    public let name: String
    public let type: String
}

// MARK: - Gas Estimation

/// Gas price estimation returned by the fullnode.
public struct GasEstimation: Codable, Sendable {
    public let gasEstimate: UInt64
    public let deprioritizedGasEstimate: UInt64?
    public let prioritizedGasEstimate: UInt64?
}

// MARK: - Table Item

/// A table item request body.
public struct TableItemRequest: Codable, Sendable {
    public let keyType: String
    public let valueType: String
    public let key: AnyCodable

    public init(keyType: String, valueType: String, key: AnyCodable) {
        self.keyType = keyType
        self.valueType = valueType
        self.key = key
    }
}

// MARK: - View Function

/// Request body for a JSON view function call.
public struct ViewRequest: Codable, Sendable {
    public let function: String
    public let typeArguments: [String]
    public let arguments: [AnyCodable]

    public init(function: String, typeArguments: [String] = [], arguments: [AnyCodable] = []) {
        self.function = function
        self.typeArguments = typeArguments
        self.arguments = arguments
    }
}

// MARK: - Faucet

/// Faucet fund request body.
public struct FaucetFundRequest: Codable, Sendable {
    public let address: String
    public let amount: UInt64

    public init(address: String, amount: UInt64) {
        self.address = address
        self.amount = amount
    }
}

/// Faucet fund response.
public struct FaucetFundResponse: Codable, Sendable {
    public let txnHashes: [String]
}

// MARK: - Block

/// Block data returned by GET /blocks.
public struct Block: Codable, Sendable {
    public let blockHeight: String
    public let blockHash: String
    public let blockTimestamp: String
    public let firstVersion: String
    public let lastVersion: String
    public let transactions: [TransactionResponse]?
}

// MARK: - AnyCodable

/// Type-erased Codable wrapper for dynamic JSON values.
public struct AnyCodable: Codable, @unchecked Sendable, Hashable {
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
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map(\.value)
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            value = dictionary.mapValues(\.value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported type")
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
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }

    public static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        String(describing: lhs.value) == String(describing: rhs.value)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(String(describing: value))
    }
}

// MARK: - Pagination Options

/// Options for paginated requests.
public struct PaginationOptions: Sendable {
    public let offset: Int?
    public let limit: Int?

    public init(offset: Int? = nil, limit: Int? = nil) {
        self.offset = offset
        self.limit = limit
    }

    public var queryParams: [String: String] {
        var params: [String: String] = [:]
        if let offset { params["start"] = String(offset) }
        if let limit { params["limit"] = String(limit) }
        return params
    }
}

// MARK: - Wait Options

/// Options for waiting for transaction confirmation.
public struct WaitForTransactionOptions: Sendable {
    public let timeoutSecs: UInt64
    public let checkSuccess: Bool
    public let waitForIndexer: Bool

    public init(
        timeoutSecs: UInt64 = 20,
        checkSuccess: Bool = true,
        waitForIndexer: Bool = false
    ) {
        self.timeoutSecs = timeoutSecs
        self.checkSuccess = checkSuccess
        self.waitForIndexer = waitForIndexer
    }
}
