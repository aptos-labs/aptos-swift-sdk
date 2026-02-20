import Foundation

/// Represents a Move type tag.
///
/// Type tags are used to describe Move types in transaction payloads
/// and for generic type parameters.
public indirect enum TypeTag: Sendable, Equatable {
    case bool
    case u8
    case u16
    case u32
    case u64
    case u128
    case u256
    case address
    case signer
    case vector(TypeTag)
    case structTag(StructTag)

    // BCS variant indices
    private var variantIndex: UInt32 {
        switch self {
        case .bool: return 0
        case .u8: return 1
        case .u64: return 2
        case .u128: return 3
        case .address: return 4
        case .signer: return 5
        case .vector: return 6
        case .structTag: return 7
        case .u16: return 8
        case .u32: return 9
        case .u256: return 10
        }
    }

    /// Parses a type tag from its string representation.
    ///
    /// Examples:
    /// - `"bool"`, `"u8"`, `"address"`
    /// - `"vector<u8>"`
    /// - `"0x1::coin::CoinStore<0x1::aptos_coin::AptosCoin>"`
    public static func fromString(_ str: String) throws -> TypeTag {
        var parser = TypeTagParser(input: str)
        return try parser.parse()
    }
}

// MARK: - BCS

extension TypeTag: BCSSerializable, BCSDeserializable {
    public func serialize(to serializer: inout Serializer) throws {
        try serializer.serializeU32AsUleb128(variantIndex)
        switch self {
        case .bool, .u8, .u16, .u32, .u64, .u128, .u256, .address, .signer:
            break
        case .vector(let inner):
            try inner.serialize(to: &serializer)
        case .structTag(let tag):
            try tag.serialize(to: &serializer)
        }
    }

    public static func deserialize(from deserializer: inout Deserializer) throws -> TypeTag {
        let variant = try deserializer.deserializeUleb128()
        switch variant {
        case 0: return .bool
        case 1: return .u8
        case 2: return .u64
        case 3: return .u128
        case 4: return .address
        case 5: return .signer
        case 6: return .vector(try TypeTag.deserialize(from: &deserializer))
        case 7: return .structTag(try StructTag.deserialize(from: &deserializer))
        case 8: return .u16
        case 9: return .u32
        case 10: return .u256
        default:
            throw AptosError.serialization(.invalidData("Unknown TypeTag variant: \(variant)"))
        }
    }
}

// MARK: - CustomStringConvertible

extension TypeTag: CustomStringConvertible {
    public var description: String {
        switch self {
        case .bool: return "bool"
        case .u8: return "u8"
        case .u16: return "u16"
        case .u32: return "u32"
        case .u64: return "u64"
        case .u128: return "u128"
        case .u256: return "u256"
        case .address: return "address"
        case .signer: return "signer"
        case .vector(let inner): return "vector<\(inner)>"
        case .structTag(let tag): return tag.description
        }
    }
}

// MARK: - StructTag

/// A fully qualified Move struct type.
///
/// Format: `address::module::name<type_args...>`
public struct StructTag: Sendable, Equatable {
    public let address: AccountAddress
    public let module: String
    public let name: String
    public let typeArgs: [TypeTag]

    public init(address: AccountAddress, module: String, name: String, typeArgs: [TypeTag] = []) {
        self.address = address
        self.module = module
        self.name = name
        self.typeArgs = typeArgs
    }

    /// Parses a struct tag from its string representation.
    ///
    /// Example: `"0x1::coin::CoinStore<0x1::aptos_coin::AptosCoin>"`
    public static func fromString(_ str: String) throws -> StructTag {
        let tag = try TypeTag.fromString(str)
        guard case .structTag(let structTag) = tag else {
            throw AptosError.parse(.invalidStructTag("Expected struct tag, got: \(tag)"))
        }
        return structTag
    }
}

extension StructTag: BCSSerializable, BCSDeserializable {
    public func serialize(to serializer: inout Serializer) throws {
        try address.serialize(to: &serializer)
        try serializer.serializeStr(module)
        try serializer.serializeStr(name)
        try serializer.serializeU32AsUleb128(UInt32(typeArgs.count))
        for arg in typeArgs {
            try arg.serialize(to: &serializer)
        }
    }

    public static func deserialize(from deserializer: inout Deserializer) throws -> StructTag {
        let address = try AccountAddress.deserialize(from: &deserializer)
        let module = try deserializer.deserializeStr()
        let name = try deserializer.deserializeStr()
        let count = Int(try deserializer.deserializeUleb128())
        var typeArgs = [TypeTag]()
        typeArgs.reserveCapacity(count)
        for _ in 0..<count {
            typeArgs.append(try TypeTag.deserialize(from: &deserializer))
        }
        return StructTag(address: address, module: module, name: name, typeArgs: typeArgs)
    }
}

extension StructTag: CustomStringConvertible {
    public var description: String {
        let base = "\(address)::\(module)::\(name)"
        if typeArgs.isEmpty {
            return base
        }
        let args = typeArgs.map { $0.description }.joined(separator: ", ")
        return "\(base)<\(args)>"
    }
}

// MARK: - MoveModuleId

/// Identifies a Move module: address + module name.
public struct MoveModuleId: Sendable, Equatable {
    public let address: AccountAddress
    public let name: String

    public init(address: AccountAddress, name: String) {
        self.address = address
        self.name = name
    }

    /// Parses from "address::module_name" format.
    public static func fromString(_ str: String) throws -> MoveModuleId {
        let parts = str.split(separator: "::", maxSplits: 1)
        guard parts.count == 2 else {
            throw AptosError.parse(.invalidModuleId("Expected format 'address::module', got: \(str)"))
        }
        let address = try AccountAddress.fromHex(String(parts[0]))
        return MoveModuleId(address: address, name: String(parts[1]))
    }
}

extension MoveModuleId: BCSSerializable, BCSDeserializable {
    public func serialize(to serializer: inout Serializer) throws {
        try address.serialize(to: &serializer)
        try serializer.serializeStr(name)
    }

    public static func deserialize(from deserializer: inout Deserializer) throws -> MoveModuleId {
        let address = try AccountAddress.deserialize(from: &deserializer)
        let name = try deserializer.deserializeStr()
        return MoveModuleId(address: address, name: name)
    }
}

extension MoveModuleId: CustomStringConvertible {
    public var description: String {
        "\(address)::\(name)"
    }
}

// MARK: - TypeTag Parser

/// Recursive descent parser for TypeTag strings.
private struct TypeTagParser {
    private let input: String
    private var index: String.Index
    private var depth: Int = 0

    init(input: String) {
        self.input = input.trimmingCharacters(in: .whitespaces)
        self.index = self.input.startIndex
    }

    mutating func parse() throws -> TypeTag {
        depth += 1
        guard depth <= Serializer.maxDepth else {
            throw AptosError.parse(.invalidTypeTag("TypeTag nesting depth exceeded"))
        }
        defer { depth -= 1 }

        let tag = try parseInner()
        return tag
    }

    private mutating func parseInner() throws -> TypeTag {
        skipWhitespace()

        guard index < input.endIndex else {
            throw AptosError.parse(.invalidTypeTag("Unexpected end of type tag"))
        }

        // Try primitive types
        if tryConsume("bool") { return .bool }
        if tryConsume("u8") && !peekIsDigit() { return .u8 }
        if tryConsume("u16") && !peekIsDigit() { return .u16 }
        if tryConsume("u32") && !peekIsDigit() { return .u32 }
        if tryConsume("u64") && !peekIsDigit() { return .u64 }
        if tryConsume("u128") && !peekIsDigit() { return .u128 }
        if tryConsume("u256") && !peekIsDigit() { return .u256 }
        if tryConsume("address") { return .address }
        if tryConsume("signer") { return .signer }

        // Reset for u8/u16/etc. that failed the digit check
        let savedIndex = index

        // vector<T>
        if tryConsume("vector") {
            skipWhitespace()
            guard tryConsumeChar("<") else {
                throw AptosError.parse(.invalidTypeTag("Expected '<' after 'vector'"))
            }
            let inner = try parse()
            skipWhitespace()
            guard tryConsumeChar(">") else {
                throw AptosError.parse(.invalidTypeTag("Expected '>' to close vector type"))
            }
            return .vector(inner)
        }

        index = savedIndex

        // Must be a struct tag: address::module::name<type_args>
        return try .structTag(parseStructTag())
    }

    private mutating func parseStructTag() throws -> StructTag {
        // Parse address
        let addressStr = try parseIdentifierOrAddress()
        let address = try AccountAddress.fromHex(addressStr)

        guard tryConsume("::") else {
            throw AptosError.parse(.invalidStructTag("Expected '::' after address"))
        }

        // Parse module name
        let moduleName = try parseIdentifier()

        guard tryConsume("::") else {
            throw AptosError.parse(.invalidStructTag("Expected '::' after module name"))
        }

        // Parse struct name
        let structName = try parseIdentifier()

        // Parse optional type args
        var typeArgs: [TypeTag] = []
        skipWhitespace()
        if tryConsumeChar("<") {
            typeArgs = try parseTypeArgList()
            skipWhitespace()
            guard tryConsumeChar(">") else {
                throw AptosError.parse(.invalidStructTag("Expected '>' to close type arguments"))
            }
        }

        return StructTag(address: address, module: moduleName, name: structName, typeArgs: typeArgs)
    }

    private mutating func parseTypeArgList() throws -> [TypeTag] {
        var args: [TypeTag] = []
        args.append(try parse())

        while true {
            skipWhitespace()
            if tryConsumeChar(",") {
                skipWhitespace()
                args.append(try parse())
            } else {
                break
            }
        }
        return args
    }

    private mutating func parseIdentifierOrAddress() throws -> String {
        skipWhitespace()
        var result = ""
        while index < input.endIndex {
            let c = input[index]
            if c.isLetter || c.isNumber || c == "_" || c == "x" {
                result.append(c)
                index = input.index(after: index)
            } else {
                break
            }
        }
        guard !result.isEmpty else {
            throw AptosError.parse(.invalidTypeTag("Expected identifier or address"))
        }
        return result
    }

    private mutating func parseIdentifier() throws -> String {
        skipWhitespace()
        var result = ""
        while index < input.endIndex {
            let c = input[index]
            if c.isLetter || c.isNumber || c == "_" {
                result.append(c)
                index = input.index(after: index)
            } else {
                break
            }
        }
        guard !result.isEmpty else {
            throw AptosError.parse(.invalidTypeTag("Expected identifier"))
        }
        return result
    }

    private mutating func skipWhitespace() {
        while index < input.endIndex && input[index].isWhitespace {
            index = input.index(after: index)
        }
    }

    private mutating func tryConsume(_ str: String) -> Bool {
        let saved = index
        for c in str {
            guard index < input.endIndex && input[index] == c else {
                index = saved
                return false
            }
            index = input.index(after: index)
        }
        return true
    }

    private mutating func tryConsumeChar(_ c: Character) -> Bool {
        guard index < input.endIndex && input[index] == c else { return false }
        index = input.index(after: index)
        return true
    }

    private func peekIsDigit() -> Bool {
        guard index < input.endIndex else { return false }
        return input[index].isNumber
    }
}
