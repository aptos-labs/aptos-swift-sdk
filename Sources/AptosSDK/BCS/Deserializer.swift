import BigInt
import Foundation

// MARK: - Deserializer

/// BCS (Binary Canonical Serialization) decoder.
///
/// Deserializes values from BCS-encoded data. Maintains an internal cursor
/// that advances as data is read.
public struct Deserializer: ~Copyable, Sendable {
    /// The data being deserialized.
    private let data: Data

    /// Current read offset.
    private var offset: Int

    /// Maximum deserializable byte array length (10 MB).
    public static let maxLength = 10 * 1024 * 1024

    /// Maximum nesting depth for recursive types.
    public static let maxDepth = 128

    /// Creates a new deserializer for the given data.
    public init(data: Data) {
        self.data = data
        offset = 0
    }

    /// Creates a new deserializer from a byte array.
    public init(bytes: [UInt8]) {
        data = Data(bytes)
        offset = 0
    }

    /// Returns the number of remaining bytes.
    public var remaining: Int {
        data.count - offset
    }

    /// Asserts that all bytes have been consumed, throwing if not.
    public func assertFinished() throws {
        guard remaining == 0 else {
            throw AptosError.serialization(.remainingBytes(remaining))
        }
    }

    // MARK: - Primitives

    /// Deserializes a boolean value from a single byte.
    public mutating func deserializeBool() throws -> Bool {
        let byte = try readByte()
        switch byte {
        case 0: return false
        case 1: return true
        default:
            throw AptosError.serialization(.invalidData("Invalid bool value: \(byte)"))
        }
    }

    /// Deserializes a UInt8 from a single byte.
    public mutating func deserializeU8() throws -> UInt8 {
        try readByte()
    }

    /// Deserializes a UInt16 from 2 bytes in little-endian order.
    public mutating func deserializeU16() throws -> UInt16 {
        let bytes = try readBytes(count: 2)
        return bytes.withUnsafeBytes { $0.loadUnaligned(as: UInt16.self) }.littleEndian
    }

    /// Deserializes a UInt32 from 4 bytes in little-endian order.
    public mutating func deserializeU32() throws -> UInt32 {
        let bytes = try readBytes(count: 4)
        return bytes.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }.littleEndian
    }

    /// Deserializes a UInt64 from 8 bytes in little-endian order.
    public mutating func deserializeU64() throws -> UInt64 {
        let bytes = try readBytes(count: 8)
        return bytes.withUnsafeBytes { $0.loadUnaligned(as: UInt64.self) }.littleEndian
    }

    /// Deserializes a UInt128 from 16 bytes in little-endian order.
    public mutating func deserializeU128() throws -> BigUInt {
        let bytes = try readBytes(count: 16)
        return BigUInt.fromLittleEndianBytes(bytes)
    }

    /// Deserializes a UInt256 from 32 bytes in little-endian order.
    public mutating func deserializeU256() throws -> BigUInt {
        let bytes = try readBytes(count: 32)
        return BigUInt.fromLittleEndianBytes(bytes)
    }

    // MARK: - Signed Integers

    /// Deserializes an Int8 from a single byte.
    public mutating func deserializeI8() throws -> Int8 {
        Int8(bitPattern: try readByte())
    }

    /// Deserializes an Int16 from 2 bytes in little-endian order.
    public mutating func deserializeI16() throws -> Int16 {
        let bytes = try readBytes(count: 2)
        return bytes.withUnsafeBytes { $0.loadUnaligned(as: Int16.self) }.littleEndian
    }

    /// Deserializes an Int32 from 4 bytes in little-endian order.
    public mutating func deserializeI32() throws -> Int32 {
        let bytes = try readBytes(count: 4)
        return bytes.withUnsafeBytes { $0.loadUnaligned(as: Int32.self) }.littleEndian
    }

    /// Deserializes an Int64 from 8 bytes in little-endian order.
    public mutating func deserializeI64() throws -> Int64 {
        let bytes = try readBytes(count: 8)
        return bytes.withUnsafeBytes { $0.loadUnaligned(as: Int64.self) }.littleEndian
    }

    // MARK: - Bytes and Strings

    /// Deserializes a UTF-8 string (ULEB128 length prefix + bytes).
    public mutating func deserializeStr() throws -> String {
        let bytes = try deserializeBytes()
        guard let str = String(data: bytes, encoding: .utf8) else {
            throw AptosError.serialization(.invalidData("Invalid UTF-8 string"))
        }
        return str
    }

    /// Deserializes a byte array (ULEB128 length prefix + bytes).
    public mutating func deserializeBytes() throws -> Data {
        let length = Int(try deserializeUleb128())
        guard length <= Self.maxLength else {
            throw AptosError.serialization(.maxLengthExceeded(
                "Byte array length \(length) exceeds max \(Self.maxLength)"
            ))
        }
        return try readBytes(count: length)
    }

    /// Deserializes fixed-length bytes without a length prefix.
    public mutating func deserializeFixedBytes(count: Int) throws -> Data {
        try readBytes(count: count)
    }

    // MARK: - ULEB128

    /// Deserializes a ULEB128-encoded UInt32.
    public mutating func deserializeUleb128() throws -> UInt32 {
        var value: UInt64 = 0
        var shift: UInt64 = 0

        while shift < 35 {
            let byte = try readByte()
            value |= UInt64(byte & 0x7F) << shift

            if byte & 0x80 == 0 {
                guard value <= UInt64(UInt32.max) else {
                    throw AptosError.serialization(.outOfRange(
                        "ULEB128 value \(value) exceeds UInt32.max"
                    ))
                }
                return UInt32(value)
            }
            shift += 7
        }

        throw AptosError.serialization(.invalidData("ULEB128 encoding too long"))
    }

    // MARK: - Composites

    /// Deserializes an optional value.
    public mutating func deserializeOption<T: BCSDeserializable>(_: T.Type) throws -> T? {
        let hasValue = try deserializeBool()
        if hasValue {
            return try T.deserialize(from: &self)
        }
        return nil
    }

    /// Deserializes a vector (array) of deserializable values.
    public mutating func deserializeVector<T: BCSDeserializable>(_: T.Type) throws -> [T] {
        let count = Int(try deserializeUleb128())
        var result = [T]()
        result.reserveCapacity(count)
        for _ in 0 ..< count {
            result.append(try T.deserialize(from: &self))
        }
        return result
    }

    // MARK: - Internal

    private mutating func readByte() throws -> UInt8 {
        guard offset < data.count else {
            throw AptosError.serialization(.unexpectedEnd(
                "Expected 1 byte at offset \(offset), but only \(remaining) bytes remain"
            ))
        }
        let byte = data[offset]
        offset += 1
        return byte
    }

    private mutating func readBytes(count: Int) throws -> Data {
        guard offset + count <= data.count else {
            throw AptosError.serialization(.unexpectedEnd(
                "Expected \(count) bytes at offset \(offset), but only \(remaining) bytes remain"
            ))
        }
        let bytes = data[offset ..< (offset + count)]
        offset += count
        return Data(bytes)
    }
}

// MARK: - BigUInt Extension

extension BigUInt {
    /// Creates a BigUInt from little-endian byte data.
    static func fromLittleEndianBytes(_ data: Data) -> BigUInt {
        let reversed = Data(data.reversed())
        return BigUInt(reversed)
    }
}
