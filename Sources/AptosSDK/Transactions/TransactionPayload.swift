import Foundation

// MARK: - TransactionPayload

/// Transaction payload types supported by the Aptos blockchain.
///
/// Each variant corresponds to a BCS enum variant index used during serialization.
public enum TransactionPayload: Sendable, Equatable {
    /// Script payload (variant 0).
    case script(Script)
    /// Entry function payload (variant 2).
    case entryFunction(EntryFunction)
    /// Multisig payload (variant 3).
    case multisig(MultisigPayload)

    private var variantIndex: UInt32 {
        switch self {
        case .script: 0
        case .entryFunction: 2
        case .multisig: 3
        }
    }
}

// MARK: BCSSerializable, BCSDeserializable

extension TransactionPayload: BCSSerializable, BCSDeserializable {
    public func serialize(to serializer: inout Serializer) throws {
        try serializer.serializeU32AsUleb128(variantIndex)
        switch self {
        case let .script(s):
            try s.serialize(to: &serializer)
        case let .entryFunction(ef):
            try ef.serialize(to: &serializer)
        case let .multisig(ms):
            try ms.serialize(to: &serializer)
        }
    }

    public static func deserialize(from deserializer: inout Deserializer) throws -> TransactionPayload {
        let variant = try deserializer.deserializeUleb128()
        switch variant {
        case 0: return .script(try Script.deserialize(from: &deserializer))
        case 2: return .entryFunction(try EntryFunction.deserialize(from: &deserializer))
        case 3: return .multisig(try MultisigPayload.deserialize(from: &deserializer))
        default:
            throw AptosError.serialization(.invalidData("Unknown TransactionPayload variant: \(variant)"))
        }
    }
}

// MARK: - EntryFunction

/// An entry function call payload.
///
/// Represents a call to a Move module's entry function on-chain. Each argument
/// must be independently BCS-serialized before being placed into `args`.
public struct EntryFunction: Sendable, Equatable {
    /// The Move module containing the function (e.g., `0x1::aptos_account`).
    public let moduleId: MoveModuleId

    /// The name of the entry function to invoke.
    public let functionName: String

    /// Type arguments for generic functions (e.g., coin type for `transfer_coins`).
    public let typeArgs: [TypeTag]

    /// BCS-encoded arguments, one `Data` per function parameter.
    public let args: [Data]

    public init(moduleId: MoveModuleId, functionName: String, typeArgs: [TypeTag] = [], args: [Data] = []) {
        self.moduleId = moduleId
        self.functionName = functionName
        self.typeArgs = typeArgs
        self.args = args
    }

    /// Convenience: creates an APT transfer entry function.
    public static func aptTransfer(to: AccountAddress, amount: UInt64) throws -> Self {
        var amountSerializer = Serializer()
        amountSerializer.serializeU64(amount)
        return Self(
            moduleId: MoveModuleId(address: .one, name: "aptos_account"),
            functionName: "transfer",
            typeArgs: [],
            args: [try bcsToBytes(to), amountSerializer.toBytes()]
        )
    }

    /// Convenience: creates a coin transfer entry function.
    public static func coinTransfer(coinType: TypeTag, to: AccountAddress, amount: UInt64) throws -> Self {
        var amountSerializer = Serializer()
        amountSerializer.serializeU64(amount)
        return Self(
            moduleId: MoveModuleId(address: .one, name: "aptos_account"),
            functionName: "transfer_coins",
            typeArgs: [coinType],
            args: [try bcsToBytes(to), amountSerializer.toBytes()]
        )
    }
}

// MARK: BCSSerializable, BCSDeserializable

extension EntryFunction: BCSSerializable, BCSDeserializable {
    public func serialize(to serializer: inout Serializer) throws {
        try moduleId.serialize(to: &serializer)
        try serializer.serializeStr(functionName)
        try serializer.serializeU32AsUleb128(UInt32(typeArgs.count))
        for tag in typeArgs {
            try tag.serialize(to: &serializer)
        }
        try serializer.serializeU32AsUleb128(UInt32(args.count))
        for arg in args {
            try serializer.serializeBytes(arg)
        }
    }

    public static func deserialize(from deserializer: inout Deserializer) throws -> EntryFunction {
        let moduleId = try MoveModuleId.deserialize(from: &deserializer)
        let funcName = try deserializer.deserializeStr()
        let typeArgCount = Int(try deserializer.deserializeUleb128())
        var typeArgs = [TypeTag]()
        for _ in 0 ..< typeArgCount {
            typeArgs.append(try TypeTag.deserialize(from: &deserializer))
        }
        let argCount = Int(try deserializer.deserializeUleb128())
        var args = [Data]()
        for _ in 0 ..< argCount {
            args.append(try deserializer.deserializeBytes())
        }
        return EntryFunction(moduleId: moduleId, functionName: funcName, typeArgs: typeArgs, args: args)
    }
}

// MARK: - Script

/// A script payload containing compiled Move bytecode to execute directly.
public struct Script: Sendable, Equatable {
    /// The compiled Move script bytecode.
    public let code: Data

    /// Type arguments for the script's generic parameters.
    public let typeArgs: [TypeTag]

    /// Typed arguments passed to the script.
    public let args: [ScriptArgument]

    public init(code: Data, typeArgs: [TypeTag] = [], args: [ScriptArgument] = []) {
        self.code = code
        self.typeArgs = typeArgs
        self.args = args
    }
}

// MARK: BCSSerializable, BCSDeserializable

extension Script: BCSSerializable, BCSDeserializable {
    public func serialize(to serializer: inout Serializer) throws {
        try serializer.serializeBytes(code)
        try serializer.serializeU32AsUleb128(UInt32(typeArgs.count))
        for tag in typeArgs {
            try tag.serialize(to: &serializer)
        }
        try serializer.serializeVector(args)
    }

    public static func deserialize(from deserializer: inout Deserializer) throws -> Script {
        let code = try deserializer.deserializeBytes()
        let typeArgCount = Int(try deserializer.deserializeUleb128())
        var typeArgs = [TypeTag]()
        for _ in 0 ..< typeArgCount {
            typeArgs.append(try TypeTag.deserialize(from: &deserializer))
        }
        let args = try deserializer.deserializeVector(ScriptArgument.self)
        return Script(code: code, typeArgs: typeArgs, args: args)
    }
}

// MARK: - ScriptArgument

/// A typed argument for a Move script, serialized with a variant tag identifying the type.
public enum ScriptArgument: Sendable, Equatable {
    case u8(UInt8)
    case u64(UInt64)
    case u128(Data)
    case address(AccountAddress)
    case u8Vector(Data)
    case bool(Bool)
    case u16(UInt16)
    case u32(UInt32)
    case u256(Data)

    private var variantIndex: UInt32 {
        switch self {
        case .u8: 0
        case .u64: 1
        case .u128: 2
        case .address: 3
        case .u8Vector: 4
        case .bool: 5
        case .u16: 6
        case .u32: 7
        case .u256: 8
        }
    }
}

// MARK: BCSSerializable, BCSDeserializable

extension ScriptArgument: BCSSerializable, BCSDeserializable {
    public func serialize(to serializer: inout Serializer) throws {
        try serializer.serializeU32AsUleb128(variantIndex)
        switch self {
        case let .u8(v): serializer.serializeU8(v)
        case let .u64(v): serializer.serializeU64(v)
        case let .u128(v): serializer.serializeFixedBytes(v)
        case let .address(v): try v.serialize(to: &serializer)
        case let .u8Vector(v): try serializer.serializeBytes(v)
        case let .bool(v): serializer.serializeBool(v)
        case let .u16(v): serializer.serializeU16(v)
        case let .u32(v): serializer.serializeU32(v)
        case let .u256(v): serializer.serializeFixedBytes(v)
        }
    }

    public static func deserialize(from deserializer: inout Deserializer) throws -> ScriptArgument {
        let variant = try deserializer.deserializeUleb128()
        switch variant {
        case 0: return .u8(try deserializer.deserializeU8())
        case 1: return .u64(try deserializer.deserializeU64())
        case 2: return .u128(try deserializer.deserializeFixedBytes(count: 16))
        case 3: return .address(try AccountAddress.deserialize(from: &deserializer))
        case 4: return .u8Vector(try deserializer.deserializeBytes())
        case 5: return .bool(try deserializer.deserializeBool())
        case 6: return .u16(try deserializer.deserializeU16())
        case 7: return .u32(try deserializer.deserializeU32())
        case 8: return .u256(try deserializer.deserializeFixedBytes(count: 32))
        default:
            throw AptosError.serialization(.invalidData("Unknown ScriptArgument variant: \(variant)"))
        }
    }
}

// MARK: - MultisigPayload

/// A multisig transaction payload targeting an on-chain multisig account.
public struct MultisigPayload: Sendable, Equatable {
    /// The address of the on-chain multisig account.
    public let multisigAddress: AccountAddress

    /// The entry function to execute, or `nil` for approval/rejection-only transactions.
    public let entryFunction: EntryFunction?

    public init(multisigAddress: AccountAddress, entryFunction: EntryFunction? = nil) {
        self.multisigAddress = multisigAddress
        self.entryFunction = entryFunction
    }
}

// MARK: BCSSerializable, BCSDeserializable

extension MultisigPayload: BCSSerializable, BCSDeserializable {
    public func serialize(to serializer: inout Serializer) throws {
        try multisigAddress.serialize(to: &serializer)
        if let ef = entryFunction {
            serializer.serializeBool(true)
            try ef.serialize(to: &serializer)
        } else {
            serializer.serializeBool(false)
        }
    }

    public static func deserialize(from deserializer: inout Deserializer) throws -> MultisigPayload {
        let addr = try AccountAddress.deserialize(from: &deserializer)
        let hasEF = try deserializer.deserializeBool()
        let ef = hasEF ? try EntryFunction.deserialize(from: &deserializer) : nil
        return MultisigPayload(multisigAddress: addr, entryFunction: ef)
    }
}
