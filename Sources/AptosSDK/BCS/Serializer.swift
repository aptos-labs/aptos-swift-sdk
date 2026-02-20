import BigInt
import Foundation

/// BCS binary serializer with growing buffer.
public struct Serializer: ~Copyable {
    private var buffer: Data
    private var offset: Int

    public init(capacity: Int = 64) {
        self.buffer = Data(count: capacity)
        self.offset = 0
    }

    // MARK: - Buffer Management

    private mutating func ensureCapacity(_ additional: Int) {
        let needed = offset + additional
        guard needed > buffer.count else { return }
        let newSize = max(
            max(buffer.count + buffer.count / 2, needed),
            buffer.count + 256
        )
        buffer.count = newSize
    }

    private mutating func writeRawBytes(_ bytes: some Collection<UInt8>) {
        let count = bytes.count
        ensureCapacity(count)
        buffer.replaceSubrange(offset ..< offset + count, with: bytes)
        offset += count
    }

    // MARK: - Primitive Serialization

    public mutating func serializeBool(_ value: Bool) {
        writeRawBytes([value ? 0x01 : 0x00])
    }

    public mutating func serializeU8(_ value: UInt8) {
        writeRawBytes([value])
    }

    public mutating func serializeU16(_ value: UInt16) {
        var le = value.littleEndian
        withUnsafeBytes(of: &le) { writeRawBytes($0) }
    }

    public mutating func serializeU32(_ value: UInt32) {
        var le = value.littleEndian
        withUnsafeBytes(of: &le) { writeRawBytes($0) }
    }

    public mutating func serializeU64(_ value: UInt64) {
        var le = value.littleEndian
        withUnsafeBytes(of: &le) { writeRawBytes($0) }
    }

    public mutating func serializeU128(_ value: BigUInt) {
        var bytes = value.serialize()
        // BigUInt.serialize() is big-endian. Pad to 16 bytes and reverse for LE.
        while bytes.count < 16 { bytes.insert(0, at: 0) }
        precondition(bytes.count == 16, "u128 value exceeds 16 bytes")
        writeRawBytes(bytes.reversed())
    }

    public mutating func serializeU256(_ value: BigUInt) {
        var bytes = value.serialize()
        while bytes.count < 32 { bytes.insert(0, at: 0) }
        precondition(bytes.count == 32, "u256 value exceeds 32 bytes")
        writeRawBytes(bytes.reversed())
    }

    // MARK: - Signed Integers

    public mutating func serializeI8(_ value: Int8) {
        serializeU8(UInt8(bitPattern: value))
    }

    public mutating func serializeI16(_ value: Int16) {
        serializeU16(UInt16(bitPattern: value))
    }

    public mutating func serializeI32(_ value: Int32) {
        serializeU32(UInt32(bitPattern: value))
    }

    public mutating func serializeI64(_ value: Int64) {
        serializeU64(UInt64(bitPattern: value))
    }

    public mutating func serializeI128(_ value: BigInt) {
        // Two's complement 16-byte LE representation
        let unsigned: BigUInt
        if value < 0 {
            unsigned = BigUInt(1) << 128 + BigUInt(value.magnitude)
            // Actually: two's complement = (2^128 - magnitude)
            let twoComp = (BigUInt(1) << 128) - value.magnitude
            var bytes = twoComp.serialize()
            while bytes.count < 16 { bytes.insert(0, at: 0) }
            precondition(bytes.count <= 16, "i128 value exceeds range")
            writeRawBytes(bytes.suffix(16).reversed())
            return
        }
        unsigned = value.magnitude
        serializeU128(unsigned)
    }

    public mutating func serializeI256(_ value: BigInt) {
        if value < 0 {
            let twoComp = (BigUInt(1) << 256) - value.magnitude
            var bytes = twoComp.serialize()
            while bytes.count < 32 { bytes.insert(0, at: 0) }
            precondition(bytes.count <= 32, "i256 value exceeds range")
            writeRawBytes(bytes.suffix(32).reversed())
            return
        }
        serializeU256(value.magnitude)
    }

    // MARK: - Variable Length Types

    public mutating func serializeStr(_ value: String) {
        let utf8 = Data(value.utf8)
        serializeU32AsUleb128(UInt32(utf8.count))
        writeRawBytes(utf8)
    }

    public mutating func serializeBytes(_ value: Data) {
        serializeU32AsUleb128(UInt32(value.count))
        writeRawBytes(value)
    }

    public mutating func serializeFixedBytes(_ value: Data) {
        writeRawBytes(value)
    }

    public mutating func serializeU32AsUleb128(_ value: UInt32) {
        var val = value
        while val >= 0x80 {
            writeRawBytes([UInt8(val & 0x7F) | 0x80])
            val >>= 7
        }
        writeRawBytes([UInt8(val)])
    }

    // MARK: - Composite Types

    public mutating func serializeVector<T: Serializable>(_ values: [T]) {
        serializeU32AsUleb128(UInt32(values.count))
        for value in values {
            value.serialize(to: &self)
        }
    }

    public mutating func serializeOption<T: Serializable>(_ value: T?) {
        if let value {
            serializeBool(true)
            value.serialize(to: &self)
        } else {
            serializeBool(false)
        }
    }

    /// Serialize a `Serializable` value directly.
    public mutating func serialize(_ value: some Serializable) {
        value.serialize(to: &self)
    }

    // MARK: - Output

    /// Extract the serialized bytes. Consumes the serializer.
    public consuming func output() -> Data {
        Data(buffer.prefix(offset))
    }
}

// MARK: - Serializable Conformances for Primitives

extension Bool: Serializable {
    public func serialize(to serializer: inout Serializer) {
        serializer.serializeBool(self)
    }
}

extension UInt8: Serializable {
    public func serialize(to serializer: inout Serializer) {
        serializer.serializeU8(self)
    }
}

extension UInt16: Serializable {
    public func serialize(to serializer: inout Serializer) {
        serializer.serializeU16(self)
    }
}

extension UInt32: Serializable {
    public func serialize(to serializer: inout Serializer) {
        serializer.serializeU32(self)
    }
}

extension UInt64: Serializable {
    public func serialize(to serializer: inout Serializer) {
        serializer.serializeU64(self)
    }
}

extension String: Serializable {
    public func serialize(to serializer: inout Serializer) {
        serializer.serializeStr(self)
    }
}

extension Data: Serializable {
    public func serialize(to serializer: inout Serializer) {
        serializer.serializeBytes(self)
    }
}
