import BigInt
import Foundation

/// Maximum allowed byte array length during deserialization (10 MB).
private let maxDeserializeBytesLength = 10 * 1024 * 1024

/// BCS binary deserializer.
public struct Deserializer {
    private let data: Data
    private var offset: Int

    public init(data: Data) {
        self.data = data
        self.offset = 0
    }

    // MARK: - Internal

    private mutating func readBytes(_ count: Int) throws -> Data {
        guard offset + count <= data.count else {
            throw AptosError.deserializationError(
                "Not enough bytes: need \(count), have \(data.count - offset)"
            )
        }
        let result = Data(data[offset ..< offset + count])
        offset += count
        return result
    }

    // MARK: - Primitives

    public mutating func deserializeBool() throws -> Bool {
        let byte = try readBytes(1)[0]
        switch byte {
        case 0x00: return false
        case 0x01: return true
        default:
            throw AptosError.deserializationError("Invalid bool value: \(byte)")
        }
    }

    public mutating func deserializeU8() throws -> UInt8 {
        try readBytes(1)[0]
    }

    public mutating func deserializeU16() throws -> UInt16 {
        let bytes = try readBytes(2)
        return bytes.withUnsafeBytes { $0.loadUnaligned(as: UInt16.self).littleEndian }
    }

    public mutating func deserializeU32() throws -> UInt32 {
        let bytes = try readBytes(4)
        return bytes.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self).littleEndian }
    }

    public mutating func deserializeU64() throws -> UInt64 {
        let bytes = try readBytes(8)
        return bytes.withUnsafeBytes { $0.loadUnaligned(as: UInt64.self).littleEndian }
    }

    public mutating func deserializeU128() throws -> BigUInt {
        let bytes = try readBytes(16)
        // LE → BE for BigUInt
        return BigUInt(Data(bytes.reversed()))
    }

    public mutating func deserializeU256() throws -> BigUInt {
        let bytes = try readBytes(32)
        return BigUInt(Data(bytes.reversed()))
    }

    // MARK: - Signed Integers

    public mutating func deserializeI8() throws -> Int8 {
        Int8(bitPattern: try deserializeU8())
    }

    public mutating func deserializeI16() throws -> Int16 {
        Int16(bitPattern: try deserializeU16())
    }

    public mutating func deserializeI32() throws -> Int32 {
        Int32(bitPattern: try deserializeU32())
    }

    public mutating func deserializeI64() throws -> Int64 {
        Int64(bitPattern: try deserializeU64())
    }

    public mutating func deserializeI128() throws -> BigInt {
        let raw = try deserializeU128()
        let limit = BigUInt(1) << 127
        if raw >= limit {
            return BigInt(raw) - BigInt(BigUInt(1) << 128)
        }
        return BigInt(raw)
    }

    public mutating func deserializeI256() throws -> BigInt {
        let raw = try deserializeU256()
        let limit = BigUInt(1) << 255
        if raw >= limit {
            return BigInt(raw) - BigInt(BigUInt(1) << 256)
        }
        return BigInt(raw)
    }

    // MARK: - Variable Length

    public mutating func deserializeStr() throws -> String {
        let bytes = try deserializeBytes()
        guard let str = String(data: bytes, encoding: .utf8) else {
            throw AptosError.deserializationError("Invalid UTF-8 string")
        }
        return str
    }

    public mutating func deserializeBytes() throws -> Data {
        let length = Int(try deserializeUleb128())
        guard length <= maxDeserializeBytesLength else {
            throw AptosError.deserializationError(
                "Byte array length \(length) exceeds maximum \(maxDeserializeBytesLength)"
            )
        }
        return try readBytes(length)
    }

    public mutating func deserializeFixedBytes(_ count: Int) throws -> Data {
        try readBytes(count)
    }

    public mutating func deserializeUleb128() throws -> UInt32 {
        var value: UInt32 = 0
        var shift: UInt32 = 0
        while shift < 35 {
            let byte = try deserializeU8()
            value |= UInt32(byte & 0x7F) << shift
            if byte & 0x80 == 0 {
                return value
            }
            shift += 7
        }
        throw AptosError.deserializationError("ULEB128 value too large")
    }

    // MARK: - Composite

    public mutating func deserializeVector<T: Deserializable>() throws -> [T] {
        let count = Int(try deserializeUleb128())
        var result: [T] = []
        result.reserveCapacity(count)
        for _ in 0 ..< count {
            result.append(try T.deserialize(from: &self))
        }
        return result
    }

    public mutating func deserializeOption<T: Deserializable>() throws -> T? {
        let hasValue = try deserializeBool()
        return hasValue ? try T.deserialize(from: &self) : nil
    }

    // MARK: - State

    /// Number of unconsumed bytes remaining.
    public var remaining: Int {
        data.count - offset
    }

    /// Throw if there are unconsumed bytes.
    public func assertFinished() throws {
        guard remaining == 0 else {
            throw AptosError.deserializationError(
                "\(remaining) bytes remaining after deserialization"
            )
        }
    }
}
