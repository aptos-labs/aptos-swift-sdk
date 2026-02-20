import Foundation

/// Transaction payload variants.
public enum TransactionPayload: Serializable, Deserializable, Sendable, Hashable {
    case entryFunction(EntryFunction)
    case script(Script)
    case multisig(Multisig)

    private enum Variant: UInt32 {
        case script = 0
        case entryFunction = 2
        case multisig = 3
    }

    public func serialize(to serializer: inout Serializer) {
        switch self {
        case .entryFunction(let ef):
            serializer.serializeU32AsUleb128(Variant.entryFunction.rawValue)
            ef.serialize(to: &serializer)
        case .script(let s):
            serializer.serializeU32AsUleb128(Variant.script.rawValue)
            s.serialize(to: &serializer)
        case .multisig(let m):
            serializer.serializeU32AsUleb128(Variant.multisig.rawValue)
            m.serialize(to: &serializer)
        }
    }

    public static func deserialize(from deserializer: inout Deserializer) throws -> TransactionPayload {
        let variant = try deserializer.deserializeUleb128()
        switch variant {
        case Variant.entryFunction.rawValue:
            return .entryFunction(try EntryFunction.deserialize(from: &deserializer))
        case Variant.script.rawValue:
            return .script(try Script.deserialize(from: &deserializer))
        case Variant.multisig.rawValue:
            return .multisig(try Multisig.deserialize(from: &deserializer))
        default:
            throw AptosError.deserializationError("Unknown TransactionPayload variant: \(variant)")
        }
    }
}

/// An entry function call payload.
public struct EntryFunction: Serializable, Deserializable, Sendable, Hashable {
    public let moduleName: ModuleId
    public let functionName: String
    public let typeArguments: [TypeTag]
    public let arguments: [Data]  // BCS-encoded arguments

    public init(
        moduleName: ModuleId,
        functionName: String,
        typeArguments: [TypeTag] = [],
        arguments: [Data] = []
    ) {
        self.moduleName = moduleName
        self.functionName = functionName
        self.typeArguments = typeArguments
        self.arguments = arguments
    }

    /// Create from a Move function ID string like `"0x1::aptos_account::transfer"`.
    public static func natural(
        _ functionId: String,
        typeArguments: [TypeTag] = [],
        arguments: [Data] = []
    ) throws -> EntryFunction {
        let parts = functionId.components(separatedBy: "::")
        guard parts.count == 3 else {
            throw AptosError.invalidArgument(
                "Function ID must have format 'address::module::function', got: \(functionId)"
            )
        }
        let address = try AccountAddress.fromString(parts[0])
        return EntryFunction(
            moduleName: ModuleId(address: address, name: parts[1]),
            functionName: parts[2],
            typeArguments: typeArguments,
            arguments: arguments
        )
    }

    public func serialize(to serializer: inout Serializer) {
        moduleName.serialize(to: &serializer)
        serializer.serializeStr(functionName)
        // Type arguments
        serializer.serializeU32AsUleb128(UInt32(typeArguments.count))
        for typeArg in typeArguments {
            typeArg.serialize(to: &serializer)
        }
        // Arguments (each is BCS-encoded bytes)
        serializer.serializeU32AsUleb128(UInt32(arguments.count))
        for arg in arguments {
            serializer.serializeBytes(arg)
        }
    }

    public static func deserialize(from deserializer: inout Deserializer) throws -> EntryFunction {
        let moduleName = try ModuleId.deserialize(from: &deserializer)
        let functionName = try deserializer.deserializeStr()
        let typeArgCount = Int(try deserializer.deserializeUleb128())
        var typeArgs: [TypeTag] = []
        for _ in 0 ..< typeArgCount {
            typeArgs.append(try TypeTag.deserialize(from: &deserializer))
        }
        let argCount = Int(try deserializer.deserializeUleb128())
        var args: [Data] = []
        for _ in 0 ..< argCount {
            args.append(try deserializer.deserializeBytes())
        }
        return EntryFunction(
            moduleName: moduleName,
            functionName: functionName,
            typeArguments: typeArgs,
            arguments: args
        )
    }
}

/// A Move script payload.
public struct Script: Serializable, Deserializable, Sendable, Hashable {
    public let bytecode: Data
    public let typeArguments: [TypeTag]
    public let arguments: [Data]

    public init(bytecode: Data, typeArguments: [TypeTag] = [], arguments: [Data] = []) {
        self.bytecode = bytecode
        self.typeArguments = typeArguments
        self.arguments = arguments
    }

    public func serialize(to serializer: inout Serializer) {
        serializer.serializeBytes(bytecode)
        serializer.serializeU32AsUleb128(UInt32(typeArguments.count))
        for typeArg in typeArguments {
            typeArg.serialize(to: &serializer)
        }
        serializer.serializeU32AsUleb128(UInt32(arguments.count))
        for arg in arguments {
            serializer.serializeBytes(arg)
        }
    }

    public static func deserialize(from deserializer: inout Deserializer) throws -> Script {
        let bytecode = try deserializer.deserializeBytes()
        let typeArgCount = Int(try deserializer.deserializeUleb128())
        var typeArgs: [TypeTag] = []
        for _ in 0 ..< typeArgCount {
            typeArgs.append(try TypeTag.deserialize(from: &deserializer))
        }
        let argCount = Int(try deserializer.deserializeUleb128())
        var args: [Data] = []
        for _ in 0 ..< argCount {
            args.append(try deserializer.deserializeBytes())
        }
        return Script(bytecode: bytecode, typeArguments: typeArgs, arguments: args)
    }
}

/// A multisig transaction payload.
public struct Multisig: Serializable, Deserializable, Sendable, Hashable {
    public let multisigAddress: AccountAddress
    public let entryFunction: EntryFunction?

    public init(multisigAddress: AccountAddress, entryFunction: EntryFunction? = nil) {
        self.multisigAddress = multisigAddress
        self.entryFunction = entryFunction
    }

    public func serialize(to serializer: inout Serializer) {
        multisigAddress.serialize(to: &serializer)
        serializer.serializeOption(entryFunction)
    }

    public static func deserialize(from deserializer: inout Deserializer) throws -> Multisig {
        let addr = try AccountAddress.deserialize(from: &deserializer)
        let ef: EntryFunction? = try deserializer.deserializeOption()
        return Multisig(multisigAddress: addr, entryFunction: ef)
    }
}

/// Input data for building an entry function transaction.
public struct InputEntryFunctionData: Sendable {
    public let function: String
    public let functionArguments: [AnyEncodable]
    public let typeArguments: [String]
    public let abi: EntryFunctionABI?

    public init(
        function: String,
        functionArguments: [AnyEncodable] = [],
        typeArguments: [String] = [],
        abi: EntryFunctionABI? = nil
    ) {
        self.function = function
        self.functionArguments = functionArguments
        self.typeArguments = typeArguments
        self.abi = abi
    }
}

/// ABI information for an entry function.
public struct EntryFunctionABI: Sendable {
    public let parameters: [TypeTag]

    public init(parameters: [TypeTag]) {
        self.parameters = parameters
    }
}

/// A type-erased encodable value for function arguments.
public struct AnyEncodable: @unchecked Sendable {
    public let value: Any

    public init(_ value: Any) {
        self.value = value
    }
}
