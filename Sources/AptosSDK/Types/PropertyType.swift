import BigInt
import Foundation

/// User-facing property type names that map to Move type strings.
public enum PropertyType: String, Sendable, CaseIterable {
    case boolean = "BOOLEAN"
    case u8 = "U8"
    case u16 = "U16"
    case u32 = "U32"
    case u64 = "U64"
    case u128 = "U128"
    case u256 = "U256"
    case address = "ADDRESS"
    case string = "STRING"
    case array = "ARRAY"

    /// The corresponding Move type string used on-chain.
    public var moveTypeString: String {
        switch self {
        case .boolean: return "bool"
        case .u8: return "u8"
        case .u16: return "u16"
        case .u32: return "u32"
        case .u64: return "u64"
        case .u128: return "u128"
        case .u256: return "u256"
        case .address: return "address"
        case .string: return "0x1::string::String"
        case .array: return "vector<u8>"
        }
    }
}

/// A property value that can be serialized to raw bytes for on-chain storage.
public enum PropertyValue: Sendable {
    case boolean(Bool)
    case u8(UInt8)
    case u16(UInt16)
    case u32(UInt32)
    case u64(UInt64)
    case u128(BigUInt)
    case u256(BigUInt)
    case address(AccountAddress)
    case string(String)
    case array(Data)

    /// The corresponding property type.
    public var propertyType: PropertyType {
        switch self {
        case .boolean: return .boolean
        case .u8: return .u8
        case .u16: return .u16
        case .u32: return .u32
        case .u64: return .u64
        case .u128: return .u128
        case .u256: return .u256
        case .address: return .address
        case .string: return .string
        case .array: return .array
        }
    }

    /// Serialize this value to raw BCS bytes for on-chain property storage.
    public func toRawBytes() -> Data {
        var serializer = Serializer()
        switch self {
        case .boolean(let v): serializer.serializeBool(v)
        case .u8(let v): serializer.serializeU8(v)
        case .u16(let v): serializer.serializeU16(v)
        case .u32(let v): serializer.serializeU32(v)
        case .u64(let v): serializer.serializeU64(v)
        case .u128(let v): serializer.serializeU128(v)
        case .u256(let v): serializer.serializeU256(v)
        case .address(let v): v.serialize(to: &serializer)
        case .string(let v): serializer.serializeStr(v)
        case .array(let v): serializer.serializeBytes(v)
        }
        return serializer.output()
    }
}

/// Validate and prepare property arrays for digital asset transactions.
public enum PropertyUtils {
    public static func prepareProperties(
        keys: [String],
        types: [PropertyType],
        values: [PropertyValue]
    ) throws -> (keys: [String], types: [String], values: [Data]) {
        guard keys.count == types.count, types.count == values.count else {
            throw AptosError.invalidArgument(
                "propertyKeys, propertyTypes, and propertyValues must have matching lengths"
            )
        }
        return (
            keys: keys,
            types: types.map(\.moveTypeString),
            values: values.map { $0.toRawBytes() }
        )
    }
}
