import BigInt
import Foundation

/// Type tag variant indices for BCS serialization.
public enum TypeTagVariant: UInt32, Sendable {
    case bool = 0
    case u8 = 1
    case u64 = 2
    case u128 = 3
    case address = 4
    case signer = 5
    case vector = 6
    case `struct` = 7
    case u16 = 8
    case u32 = 9
    case u256 = 10
    case i8 = 11
    case i16 = 12
    case i32 = 13
    case i64 = 14
    case i128 = 15
    case i256 = 16
    case reference = 254
    case generic = 255
}

/// Represents a Move type tag used in transaction payloads for generic type arguments.
public indirect enum TypeTag: Serializable, Deserializable, Sendable, Hashable {
    case bool
    case u8
    case u16
    case u32
    case u64
    case u128
    case u256
    case i8
    case i16
    case i32
    case i64
    case i128
    case i256
    case address
    case signer
    case vector(TypeTag)
    case `struct`(StructTag)
    case reference(TypeTag)
    case generic(UInt16)

    // MARK: - Parsing

    /// Parse a type tag from its string representation.
    ///
    /// Examples: `"u64"`, `"bool"`, `"vector<u8>"`, `"0x1::coin::CoinStore<0x1::aptos_coin::AptosCoin>"`
    public static func parse(_ str: String) throws -> TypeTag {
        let trimmed = str.trimmingCharacters(in: .whitespaces)

        switch trimmed {
        case "bool": return .bool
        case "u8": return .u8
        case "u16": return .u16
        case "u32": return .u32
        case "u64": return .u64
        case "u128": return .u128
        case "u256": return .u256
        case "i8": return .i8
        case "i16": return .i16
        case "i32": return .i32
        case "i64": return .i64
        case "i128": return .i128
        case "i256": return .i256
        case "address": return .address
        case "signer": return .signer
        default: break
        }

        if trimmed.hasPrefix("vector<"), trimmed.hasSuffix(">") {
            let inner = String(trimmed.dropFirst(7).dropLast(1))
            return .vector(try parse(inner))
        }

        if trimmed.hasPrefix("&") {
            let inner = String(trimmed.dropFirst(1))
            return .reference(try parse(inner))
        }

        // Must be a struct type
        return .struct(try StructTag.parse(trimmed))
    }

    // MARK: - Serializable

    public func serialize(to serializer: inout Serializer) {
        switch self {
        case .bool: serializer.serializeU32AsUleb128(TypeTagVariant.bool.rawValue)
        case .u8: serializer.serializeU32AsUleb128(TypeTagVariant.u8.rawValue)
        case .u64: serializer.serializeU32AsUleb128(TypeTagVariant.u64.rawValue)
        case .u128: serializer.serializeU32AsUleb128(TypeTagVariant.u128.rawValue)
        case .address: serializer.serializeU32AsUleb128(TypeTagVariant.address.rawValue)
        case .signer: serializer.serializeU32AsUleb128(TypeTagVariant.signer.rawValue)
        case .vector(let inner):
            serializer.serializeU32AsUleb128(TypeTagVariant.vector.rawValue)
            inner.serialize(to: &serializer)
        case .struct(let tag):
            serializer.serializeU32AsUleb128(TypeTagVariant.struct.rawValue)
            tag.serialize(to: &serializer)
        case .u16: serializer.serializeU32AsUleb128(TypeTagVariant.u16.rawValue)
        case .u32: serializer.serializeU32AsUleb128(TypeTagVariant.u32.rawValue)
        case .u256: serializer.serializeU32AsUleb128(TypeTagVariant.u256.rawValue)
        case .i8: serializer.serializeU32AsUleb128(TypeTagVariant.i8.rawValue)
        case .i16: serializer.serializeU32AsUleb128(TypeTagVariant.i16.rawValue)
        case .i32: serializer.serializeU32AsUleb128(TypeTagVariant.i32.rawValue)
        case .i64: serializer.serializeU32AsUleb128(TypeTagVariant.i64.rawValue)
        case .i128: serializer.serializeU32AsUleb128(TypeTagVariant.i128.rawValue)
        case .i256: serializer.serializeU32AsUleb128(TypeTagVariant.i256.rawValue)
        case .reference(let inner):
            serializer.serializeU32AsUleb128(TypeTagVariant.reference.rawValue)
            inner.serialize(to: &serializer)
        case .generic(let idx):
            serializer.serializeU32AsUleb128(TypeTagVariant.generic.rawValue)
            serializer.serializeU16(idx)
        }
    }

    // MARK: - Deserializable

    public static func deserialize(from deserializer: inout Deserializer) throws -> TypeTag {
        let variant = try deserializer.deserializeUleb128()
        switch variant {
        case TypeTagVariant.bool.rawValue: return .bool
        case TypeTagVariant.u8.rawValue: return .u8
        case TypeTagVariant.u64.rawValue: return .u64
        case TypeTagVariant.u128.rawValue: return .u128
        case TypeTagVariant.address.rawValue: return .address
        case TypeTagVariant.signer.rawValue: return .signer
        case TypeTagVariant.vector.rawValue: return .vector(try TypeTag.deserialize(from: &deserializer))
        case TypeTagVariant.struct.rawValue: return .struct(try StructTag.deserialize(from: &deserializer))
        case TypeTagVariant.u16.rawValue: return .u16
        case TypeTagVariant.u32.rawValue: return .u32
        case TypeTagVariant.u256.rawValue: return .u256
        case TypeTagVariant.i8.rawValue: return .i8
        case TypeTagVariant.i16.rawValue: return .i16
        case TypeTagVariant.i32.rawValue: return .i32
        case TypeTagVariant.i64.rawValue: return .i64
        case TypeTagVariant.i128.rawValue: return .i128
        case TypeTagVariant.i256.rawValue: return .i256
        case TypeTagVariant.reference.rawValue: return .reference(try TypeTag.deserialize(from: &deserializer))
        case TypeTagVariant.generic.rawValue: return .generic(try deserializer.deserializeU16())
        default:
            throw AptosError.deserializationError("Unknown TypeTag variant: \(variant)")
        }
    }
}

// MARK: - StructTag

/// A fully qualified Move struct type, e.g. `0x1::coin::CoinStore<0x1::aptos_coin::AptosCoin>`.
public struct StructTag: Serializable, Deserializable, Sendable, Hashable {
    public let address: AccountAddress
    public let moduleName: String
    public let name: String
    public let typeArgs: [TypeTag]

    public init(address: AccountAddress, moduleName: String, name: String, typeArgs: [TypeTag] = []) {
        self.address = address
        self.moduleName = moduleName
        self.name = name
        self.typeArgs = typeArgs
    }

    /// Parse from string format: `"0x1::module::Name<TypeArgs>"`.
    public static func parse(_ str: String) throws -> StructTag {
        let trimmed = str.trimmingCharacters(in: .whitespaces)

        // Split off type arguments
        var mainPart = trimmed
        var typeArgs: [TypeTag] = []

        if let angleBracketStart = findTopLevelAngleBracket(trimmed) {
            guard trimmed.hasSuffix(">") else {
                throw AptosError.invalidArgument("Malformed struct type tag: \(str)")
            }
            let typeArgsStart = trimmed.index(angleBracketStart, offsetBy: 1)
            let typeArgsEnd = trimmed.index(before: trimmed.endIndex)
            let typeArgsStr = String(trimmed[typeArgsStart ..< typeArgsEnd])
            typeArgs = try splitTypeArgs(typeArgsStr).map { try TypeTag.parse($0) }
            mainPart = String(trimmed[trimmed.startIndex ..< angleBracketStart])
        }

        // Split address::module::name
        let parts = mainPart.split(separator: ":", maxSplits: .max, omittingEmptySubsequences: false)
        // Expected: ["0x1", "", "module", "", "name"]
        var components: [String] = []
        var i = 0
        while i < parts.count {
            if i + 1 < parts.count, parts[i + 1].isEmpty {
                // This was a "::" separator
                i += 2
                continue
            }
            components.append(String(parts[i]))
            i += 1
        }

        // Re-parse more simply: split on "::"
        let doubleSplit = mainPart.components(separatedBy: "::")
        guard doubleSplit.count == 3 else {
            throw AptosError.invalidArgument(
                "Struct type tag must have format address::module::name, got: \(mainPart)"
            )
        }

        let address = try AccountAddress.fromString(doubleSplit[0])
        return StructTag(
            address: address,
            moduleName: doubleSplit[1],
            name: doubleSplit[2],
            typeArgs: typeArgs
        )
    }

    // MARK: - Serializable

    public func serialize(to serializer: inout Serializer) {
        address.serialize(to: &serializer)
        serializer.serializeStr(moduleName)
        serializer.serializeStr(name)
        serializer.serializeU32AsUleb128(UInt32(typeArgs.count))
        for arg in typeArgs {
            arg.serialize(to: &serializer)
        }
    }

    // MARK: - Deserializable

    public static func deserialize(from deserializer: inout Deserializer) throws -> StructTag {
        let address = try AccountAddress.deserialize(from: &deserializer)
        let moduleName = try deserializer.deserializeStr()
        let name = try deserializer.deserializeStr()
        let count = Int(try deserializer.deserializeUleb128())
        var typeArgs: [TypeTag] = []
        for _ in 0 ..< count {
            typeArgs.append(try TypeTag.deserialize(from: &deserializer))
        }
        return StructTag(address: address, moduleName: moduleName, name: name, typeArgs: typeArgs)
    }
}

extension StructTag: CustomStringConvertible {
    public var description: String {
        var result = "\(address)::\(moduleName)::\(name)"
        if !typeArgs.isEmpty {
            result += "<" + typeArgs.map { "\($0)" }.joined(separator: ", ") + ">"
        }
        return result
    }
}

// MARK: - Parsing Helpers

/// Find the index of the first top-level `<` in a type string (not nested).
private func findTopLevelAngleBracket(_ str: String) -> String.Index? {
    var depth = 0
    for idx in str.indices {
        switch str[idx] {
        case "<" where depth == 0: return idx
        case "<": depth += 1
        case ">": depth -= 1
        default: break
        }
    }
    return nil
}

/// Split type arguments at the top level (respecting nested `<>`).
private func splitTypeArgs(_ str: String) throws -> [String] {
    var result: [String] = []
    var depth = 0
    var current = ""
    for char in str {
        switch char {
        case "<": depth += 1; current.append(char)
        case ">": depth -= 1; current.append(char)
        case "," where depth == 0:
            result.append(current.trimmingCharacters(in: .whitespaces))
            current = ""
        default: current.append(char)
        }
    }
    let trimmed = current.trimmingCharacters(in: .whitespaces)
    if !trimmed.isEmpty {
        result.append(trimmed)
    }
    return result
}
