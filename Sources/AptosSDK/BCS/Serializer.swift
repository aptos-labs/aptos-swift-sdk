import Foundation
import BigInt

/// BCS (Binary Canonical Serialization) encoder.
///
/// Serializes values into the BCS format used by the Aptos blockchain.
/// The serializer maintains an internal buffer that grows as needed.
public struct Serializer: ~Copyable, Sendable {
    /// The internal buffer for serialized data.
    private var buffer: Data

    /// Maximum serializable byte array length (10 MB).
    public static let maxLength: Int = 10 * 1024 * 1024

    /// Maximum ULEB128 value.
    public static let maxULEB128: UInt32 = UInt32.max

    /// Maximum nesting depth for recursive types.
    public static let maxDepth: Int = 128

    /// Creates a new serializer with the specified initial capacity.
    public init(capacity: Int = 64) {
        buffer = Data(capacity: capacity)
    }

    /// Returns the serialized bytes.
    public consuming func toBytes() -> Data {
        buffer
    }

    // MARK: - Primitives

    /// Serializes a boolean value as a single byte (0x00 or 0x01).
    public mutating func serializeBool(_ value: Bool) {
        buffer.append(value ? 1 : 0)
    }

    /// Serializes a UInt8 value as a single byte.
    public mutating func serializeU8(_ value: UInt8) {
        buffer.append(value)
    }

    /// Serializes a UInt16 value as 2 bytes in little-endian order.
    public mutating func serializeU16(_ value: UInt16) {
        withUnsafeBytes(of: value.littleEndian) { buffer.append(contentsOf: $0) }
    }

    /// Serializes a UInt32 value as 4 bytes in little-endian order.
    public mutating func serializeU32(_ value: UInt32) {
        withUnsafeBytes(of: value.littleEndian) { buffer.append(contentsOf: $0) }
    }

    /// Serializes a UInt64 value as 8 bytes in little-endian order.
    public mutating func serializeU64(_ value: UInt64) {
        withUnsafeBytes(of: value.littleEndian) { buffer.append(contentsOf: $0) }
    }

    /// Serializes a UInt128 value (as BigUInt) as 16 bytes in little-endian order.
    public mutating func serializeU128(_ value: BigUInt) throws {
        let maxU128 = (BigUInt(1) << 128) - 1
        guard value <= maxU128 else {
            throw AptosError.serialization(.outOfRange("Value \(value) exceeds U128 max"))
        }
        let data = value.littleEndianData(count: 16)
        buffer.append(data)
    }

    /// Serializes a UInt256 value (as BigUInt) as 32 bytes in little-endian order.
    public mutating func serializeU256(_ value: BigUInt) throws {
        let maxU256 = (BigUInt(1) << 256) - 1
        guard value <= maxU256 else {
            throw AptosError.serialization(.outOfRange("Value \(value) exceeds U256 max"))
        }
        let data = value.littleEndianData(count: 32)
        buffer.append(data)
    }

    // MARK: - Signed Integers

    /// Serializes an Int8 value as a single byte (two's complement).
    public mutating func serializeI8(_ value: Int8) {
        buffer.append(UInt8(bitPattern: value))
    }

    /// Serializes an Int16 value as 2 bytes in little-endian order.
    public mutating func serializeI16(_ value: Int16) {
        withUnsafeBytes(of: value.littleEndian) { buffer.append(contentsOf: $0) }
    }

    /// Serializes an Int32 value as 4 bytes in little-endian order.
    public mutating func serializeI32(_ value: Int32) {
        withUnsafeBytes(of: value.littleEndian) { buffer.append(contentsOf: $0) }
    }

    /// Serializes an Int64 value as 8 bytes in little-endian order.
    public mutating func serializeI64(_ value: Int64) {
        withUnsafeBytes(of: value.littleEndian) { buffer.append(contentsOf: $0) }
    }

    // MARK: - Bytes and Strings

    /// Serializes a string as ULEB128 length prefix + UTF-8 bytes.
    public mutating func serializeStr(_ value: String) throws {
        let bytes = Array(value.utf8)
        try serializeBytes(bytes)
    }

    /// Serializes a byte array with ULEB128 length prefix.
    public mutating func serializeBytes(_ value: some Collection<UInt8>) throws {
        let length = value.count
        guard length <= Self.maxLength else {
            throw AptosError.serialization(.maxLengthExceeded(
                "Byte array length \(length) exceeds max \(Self.maxLength)"))
        }
        try serializeU32AsUleb128(UInt32(length))
        buffer.append(contentsOf: value)
    }

    /// Serializes raw bytes without a length prefix.
    public mutating func serializeFixedBytes(_ value: some Collection<UInt8>) {
        buffer.append(contentsOf: value)
    }

    // MARK: - ULEB128

    /// Serializes a UInt32 as a variable-length ULEB128 encoding.
    public mutating func serializeU32AsUleb128(_ value: UInt32) throws {
        var val = value
        while val >= 0x80 {
            buffer.append(UInt8(val & 0x7F) | 0x80)
            val >>= 7
        }
        buffer.append(UInt8(val))
    }

    // MARK: - Composites

    /// Serializes an optional value: 0x00 for nil, 0x01 + serialized value for some.
    public mutating func serializeOption<T: BCSSerializable>(_ value: T?) throws {
        if let value {
            serializeBool(true)
            try value.serialize(to: &self)
        } else {
            serializeBool(false)
        }
    }

    /// Serializes a vector (array) as ULEB128 count + serialized elements.
    public mutating func serializeVector<T: BCSSerializable>(_ values: [T]) throws {
        try serializeU32AsUleb128(UInt32(values.count))
        for value in values {
            try value.serialize(to: &self)
        }
    }

    /// Serializes a vector of bytes (each as U8) with ULEB128 count prefix.
    public mutating func serializeVectorU8(_ values: [UInt8]) throws {
        try serializeBytes(values)
    }
}

// MARK: - BigUInt Extension

extension BigUInt {
    /// Returns little-endian byte representation padded/truncated to `count` bytes.
    func littleEndianData(count: Int) -> Data {
        var result = Data(repeating: 0, count: count)
        var value = self
        for i in 0..<count {
            result[i] = UInt8(value & 0xFF)
            value >>= 8
        }
        return result
    }
}
