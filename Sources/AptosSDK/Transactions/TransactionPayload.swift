import Foundation

/// Transaction payload types.
public enum TransactionPayload: Sendable, Equatable {
    /// Script payload (variant 0).
    case script(Script)
    /// Entry function payload (variant 2).
    case entryFunction(EntryFunction)
    /// Multisig payload (variant 3).
    case multisig(MultisigPayload)

    private var variantIndex: UInt32 {
        switch self {
        case .script: return 0
        case .entryFunction: return 2
        case .multisig: return 3
        }
    }
}

extension TransactionPayload: BCSSerializable, BCSDeserializable {
    public func serialize(to serializer: inout Serializer) throws {
        try serializer.serializeU32AsUleb128(variantIndex)
        switch self {
        case .script(let s):
            try s.serialize(to: &serializer)
        case .entryFunction(let ef):
            try ef.serialize(to: &serializer)
        case .multisig(let ms):
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

// MARK: - Entry Function

/// An entry function call payload.
public struct EntryFunction: Sendable, Equatable {
    public let moduleId: MoveModuleId
    public let functionName: String
    public let typeArgs: [TypeTag]
    public let args: [Data]

    public init(moduleId: MoveModuleId, functionName: String, typeArgs: [TypeTag] = [], args: [Data] = []) {
        self.moduleId = moduleId
        self.functionName = functionName
        self.typeArgs = typeArgs
        self.args = args
    }

    /// Convenience: creates an APT transfer entry function.
    public static func aptTransfer(to: AccountAddress, amount: UInt64) -> EntryFunction {
        var amountSerializer = Serializer()
        amountSerializer.serializeU64(amount)
        return EntryFunction(
            moduleId: MoveModuleId(address: .one, name: "aptos_account"),
            functionName: "transfer",
            typeArgs: [],
            args: [try! bcsToBytes(to), amountSerializer.toBytes()]
        )
    }

    /// Convenience: creates a coin transfer entry function.
    public static func coinTransfer(coinType: TypeTag, to: AccountAddress, amount: UInt64) -> EntryFunction {
        var amountSerializer = Serializer()
        amountSerializer.serializeU64(amount)
        return EntryFunction(
            moduleId: MoveModuleId(address: .one, name: "aptos_account"),
            functionName: "transfer_coins",
            typeArgs: [coinType],
            args: [try! bcsToBytes(to), amountSerializer.toBytes()]
        )
    }
}

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
        for _ in 0..<typeArgCount {
            typeArgs.append(try TypeTag.deserialize(from: &deserializer))
        }
        let argCount = Int(try deserializer.deserializeUleb128())
        var args = [Data]()
        for _ in 0..<argCount {
            args.append(try deserializer.deserializeBytes())
        }
        return EntryFunction(moduleId: moduleId, functionName: funcName, typeArgs: typeArgs, args: args)
    }
}

// MARK: - Script

/// A script payload with bytecode.
public struct Script: Sendable, Equatable {
    public let code: Data
    public let typeArgs: [TypeTag]
    public let args: [ScriptArgument]

    public init(code: Data, typeArgs: [TypeTag] = [], args: [ScriptArgument] = []) {
        self.code = code
        self.typeArgs = typeArgs
        self.args = args
    }
}

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
        for _ in 0..<typeArgCount {
            typeArgs.append(try TypeTag.deserialize(from: &deserializer))
        }
        let args = try deserializer.deserializeVector(ScriptArgument.self)
        return Script(code: code, typeArgs: typeArgs, args: args)
    }
}

/// Script function argument.
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
        case .u8: return 0
        case .u64: return 1
        case .u128: return 2
        case .address: return 3
        case .u8Vector: return 4
        case .bool: return 5
        case .u16: return 6
        case .u32: return 7
        case .u256: return 8
        }
    }
}

extension ScriptArgument: BCSSerializable, BCSDeserializable {
    public func serialize(to serializer: inout Serializer) throws {
        try serializer.serializeU32AsUleb128(variantIndex)
        switch self {
        case .u8(let v): serializer.serializeU8(v)
        case .u64(let v): serializer.serializeU64(v)
        case .u128(let v): serializer.serializeFixedBytes(v)
        case .address(let v): try v.serialize(to: &serializer)
        case .u8Vector(let v): try serializer.serializeBytes(v)
        case .bool(let v): serializer.serializeBool(v)
        case .u16(let v): serializer.serializeU16(v)
        case .u32(let v): serializer.serializeU32(v)
        case .u256(let v): serializer.serializeFixedBytes(v)
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

// MARK: - Multisig Payload

/// A multisig transaction payload.
public struct MultisigPayload: Sendable, Equatable {
    public let multisigAddress: AccountAddress
    public let entryFunction: EntryFunction?

    public init(multisigAddress: AccountAddress, entryFunction: EntryFunction? = nil) {
        self.multisigAddress = multisigAddress
        self.entryFunction = entryFunction
    }
}

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
