import BigInt
import Foundation
import XCTest

@testable import AptosSDK

final class SerializerTests: XCTestCase {

    // MARK: - Bool

    func testSerializeBoolTrue() {
        var s = Serializer()
        s.serializeBool(true)
        let bytes = s.output()
        XCTAssertEqual(bytes, Data([0x01]))
    }

    func testSerializeBoolFalse() {
        var s = Serializer()
        s.serializeBool(false)
        let bytes = s.output()
        XCTAssertEqual(bytes, Data([0x00]))
    }

    func testBoolRoundTrip() throws {
        for value in [true, false] {
            var s = Serializer()
            s.serializeBool(value)
            let bytes = s.output()
            var d = Deserializer(data: bytes)
            let result = try d.deserializeBool()
            XCTAssertEqual(result, value)
        }
    }

    // MARK: - U8

    func testSerializeU8() {
        var s = Serializer()
        s.serializeU8(0)
        XCTAssertEqual(s.output(), Data([0x00]))

        var s2 = Serializer()
        s2.serializeU8(255)
        XCTAssertEqual(s2.output(), Data([0xFF]))
    }

    func testU8RoundTrip() throws {
        for value: UInt8 in [0, 1, 127, 128, 255] {
            var s = Serializer()
            s.serializeU8(value)
            let bytes = s.output()
            var d = Deserializer(data: bytes)
            let result = try d.deserializeU8()
            XCTAssertEqual(result, value)
        }
    }

    // MARK: - U16

    func testSerializeU16LittleEndian() {
        var s = Serializer()
        s.serializeU16(0x0102)
        let bytes = s.output()
        // Little-endian: low byte first
        XCTAssertEqual(bytes, Data([0x02, 0x01]))
    }

    func testU16RoundTrip() throws {
        for value: UInt16 in [0, 1, 256, UInt16.max] {
            var s = Serializer()
            s.serializeU16(value)
            let bytes = s.output()
            var d = Deserializer(data: bytes)
            let result = try d.deserializeU16()
            XCTAssertEqual(result, value)
        }
    }

    // MARK: - U32

    func testSerializeU32LittleEndian() {
        var s = Serializer()
        s.serializeU32(0x01020304)
        let bytes = s.output()
        XCTAssertEqual(bytes, Data([0x04, 0x03, 0x02, 0x01]))
    }

    func testU32RoundTrip() throws {
        for value: UInt32 in [0, 1, 65536, UInt32.max] {
            var s = Serializer()
            s.serializeU32(value)
            let bytes = s.output()
            var d = Deserializer(data: bytes)
            let result = try d.deserializeU32()
            XCTAssertEqual(result, value)
        }
    }

    // MARK: - U64

    func testSerializeU64LittleEndian() {
        var s = Serializer()
        s.serializeU64(1)
        let bytes = s.output()
        XCTAssertEqual(bytes, Data([0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]))
    }

    func testU64MaxRoundTrip() throws {
        let value: UInt64 = UInt64.max
        var s = Serializer()
        s.serializeU64(value)
        let bytes = s.output()
        XCTAssertEqual(bytes.count, 8)
        var d = Deserializer(data: bytes)
        let result = try d.deserializeU64()
        XCTAssertEqual(result, value)
    }

    func testU64RoundTrip() throws {
        for value: UInt64 in [0, 1, 1_000_000, UInt64.max] {
            var s = Serializer()
            s.serializeU64(value)
            let bytes = s.output()
            var d = Deserializer(data: bytes)
            let result = try d.deserializeU64()
            XCTAssertEqual(result, value)
        }
    }

    // MARK: - U128

    func testSerializeU128Zero() {
        var s = Serializer()
        s.serializeU128(BigUInt(0))
        let bytes = s.output()
        XCTAssertEqual(bytes.count, 16)
        XCTAssertEqual(bytes, Data(repeating: 0, count: 16))
    }

    func testSerializeU128One() {
        var s = Serializer()
        s.serializeU128(BigUInt(1))
        let bytes = s.output()
        XCTAssertEqual(bytes.count, 16)
        // LE: first byte is 1, rest are 0
        var expected = Data(repeating: 0, count: 16)
        expected[0] = 0x01
        XCTAssertEqual(bytes, expected)
    }

    func testU128MaxRoundTrip() throws {
        let maxU128 = (BigUInt(1) << 128) - 1
        var s = Serializer()
        s.serializeU128(maxU128)
        let bytes = s.output()
        XCTAssertEqual(bytes.count, 16)
        XCTAssertEqual(bytes, Data(repeating: 0xFF, count: 16))

        var d = Deserializer(data: bytes)
        let result = try d.deserializeU128()
        XCTAssertEqual(result, maxU128)
    }

    func testU128RoundTrip() throws {
        let values: [BigUInt] = [0, 1, 255, BigUInt(UInt64.max), (BigUInt(1) << 128) - 1]
        for value in values {
            var s = Serializer()
            s.serializeU128(value)
            let bytes = s.output()
            var d = Deserializer(data: bytes)
            let result = try d.deserializeU128()
            XCTAssertEqual(result, value, "Round-trip failed for U128 value: \(value)")
        }
    }

    // MARK: - U256

    func testSerializeU256Zero() {
        var s = Serializer()
        s.serializeU256(BigUInt(0))
        let bytes = s.output()
        XCTAssertEqual(bytes.count, 32)
        XCTAssertEqual(bytes, Data(repeating: 0, count: 32))
    }

    func testU256MaxRoundTrip() throws {
        let maxU256 = (BigUInt(1) << 256) - 1
        var s = Serializer()
        s.serializeU256(maxU256)
        let bytes = s.output()
        XCTAssertEqual(bytes.count, 32)
        XCTAssertEqual(bytes, Data(repeating: 0xFF, count: 32))

        var d = Deserializer(data: bytes)
        let result = try d.deserializeU256()
        XCTAssertEqual(result, maxU256)
    }

    func testU256RoundTrip() throws {
        let values: [BigUInt] = [0, 1, BigUInt(UInt64.max), (BigUInt(1) << 128), (BigUInt(1) << 256) - 1]
        for value in values {
            var s = Serializer()
            s.serializeU256(value)
            let bytes = s.output()
            var d = Deserializer(data: bytes)
            let result = try d.deserializeU256()
            XCTAssertEqual(result, value, "Round-trip failed for U256 value: \(value)")
        }
    }

    // MARK: - Str

    func testSerializeStrEmpty() {
        var s = Serializer()
        s.serializeStr("")
        let bytes = s.output()
        // ULEB128(0) = 0x00, then no payload bytes
        XCTAssertEqual(bytes, Data([0x00]))
    }

    func testSerializeStrHello() {
        var s = Serializer()
        s.serializeStr("hello")
        let bytes = s.output()
        // ULEB128(5) = 0x05, then "hello" in UTF-8
        let expected = Data([0x05]) + Data("hello".utf8)
        XCTAssertEqual(bytes, expected)
    }

    func testStrRoundTrip() throws {
        let strings = ["", "hello", "world", "Hello, World! \u{1F600}", "aptos"]
        for str in strings {
            var s = Serializer()
            s.serializeStr(str)
            let bytes = s.output()
            var d = Deserializer(data: bytes)
            let result = try d.deserializeStr()
            XCTAssertEqual(result, str)
        }
    }

    // MARK: - Bytes

    func testSerializeBytesEmpty() {
        var s = Serializer()
        s.serializeBytes(Data())
        let bytes = s.output()
        XCTAssertEqual(bytes, Data([0x00]))
    }

    func testSerializeBytes() {
        var s = Serializer()
        s.serializeBytes(Data([0xCA, 0xFE]))
        let bytes = s.output()
        // ULEB128(2) = 0x02, then 0xCA 0xFE
        XCTAssertEqual(bytes, Data([0x02, 0xCA, 0xFE]))
    }

    func testBytesRoundTrip() throws {
        let data = Data([0x01, 0x02, 0x03, 0xFF, 0x00])
        var s = Serializer()
        s.serializeBytes(data)
        let bytes = s.output()
        var d = Deserializer(data: bytes)
        let result = try d.deserializeBytes()
        XCTAssertEqual(result, data)
    }

    // MARK: - Fixed Bytes

    func testSerializeFixedBytes() {
        var s = Serializer()
        s.serializeFixedBytes(Data([0xAB, 0xCD]))
        let bytes = s.output()
        // No length prefix for fixed bytes
        XCTAssertEqual(bytes, Data([0xAB, 0xCD]))
    }

    // MARK: - ULEB128

    func testSerializeUleb128Zero() {
        var s = Serializer()
        s.serializeU32AsUleb128(0)
        XCTAssertEqual(s.output(), Data([0x00]))
    }

    func testSerializeUleb128SingleByte() {
        var s = Serializer()
        s.serializeU32AsUleb128(127)
        XCTAssertEqual(s.output(), Data([0x7F]))
    }

    func testSerializeUleb128TwoBytes() {
        // 128 = 0x80 -> ULEB128 = [0x80, 0x01]
        var s = Serializer()
        s.serializeU32AsUleb128(128)
        XCTAssertEqual(s.output(), Data([0x80, 0x01]))
    }

    func testSerializeUleb128LargeValue() {
        // 300 = 0x12C -> ULEB128 encoding
        // 300 = 0b100101100
        // First 7 bits: 0101100 = 0x2C, with continuation: 0xAC
        // Next bits: 10 = 0x02
        var s = Serializer()
        s.serializeU32AsUleb128(300)
        XCTAssertEqual(s.output(), Data([0xAC, 0x02]))
    }

    func testUleb128RoundTrip() throws {
        let values: [UInt32] = [0, 1, 127, 128, 255, 256, 300, 16383, 16384, UInt32.max]
        for value in values {
            var s = Serializer()
            s.serializeU32AsUleb128(value)
            let bytes = s.output()
            var d = Deserializer(data: bytes)
            let result = try d.deserializeUleb128()
            XCTAssertEqual(result, value, "ULEB128 round-trip failed for value: \(value)")
        }
    }

    // MARK: - Vector (via Serializable conformance)

    func testSerializeVectorEmptyU8() throws {
        var s = Serializer()
        let items: [UInt8] = []
        s.serializeVector(items)
        let bytes = s.output()
        // ULEB128(0) = 0x00
        XCTAssertEqual(bytes, Data([0x00]))
    }

    func testSerializeVectorU8() throws {
        var s = Serializer()
        let items: [UInt8] = [1, 2, 3]
        s.serializeVector(items)
        let bytes = s.output()
        // ULEB128(3) = 0x03, then [0x01, 0x02, 0x03]
        XCTAssertEqual(bytes, Data([0x03, 0x01, 0x02, 0x03]))
    }

    func testSerializeVectorString() throws {
        var s = Serializer()
        let items = ["ab", "cd"]
        s.serializeVector(items)
        let bytes = s.output()
        // ULEB128(2) for vector length
        // then "ab" = [ULEB128(2), 0x61, 0x62]
        // then "cd" = [ULEB128(2), 0x63, 0x64]
        let expected = Data([0x02, 0x02, 0x61, 0x62, 0x02, 0x63, 0x64])
        XCTAssertEqual(bytes, expected)
    }

    func testSerializeVectorAccountAddress() throws {
        var s = Serializer()
        let items = [AccountAddress.ZERO, AccountAddress.ONE]
        s.serializeVector(items)
        let bytes = s.output()
        // ULEB128(2) + 32 bytes for ZERO + 32 bytes for ONE = 1 + 64 = 65
        XCTAssertEqual(bytes.count, 65)
        XCTAssertEqual(bytes[0], 0x02) // vector length
    }

    // MARK: - Option

    func testSerializeOptionSome() {
        var s = Serializer()
        let value: UInt8? = 42
        s.serializeOption(value)
        let bytes = s.output()
        // Bool true (0x01) + U8(42)
        XCTAssertEqual(bytes, Data([0x01, 0x2A]))
    }

    func testSerializeOptionNone() {
        var s = Serializer()
        let value: UInt8? = nil
        s.serializeOption(value)
        let bytes = s.output()
        // Bool false (0x00)
        XCTAssertEqual(bytes, Data([0x00]))
    }

    func testOptionRoundTripSome() throws {
        // Use AccountAddress which conforms to Deserializable
        var s1 = Serializer()
        let someValue: AccountAddress? = AccountAddress.ONE
        s1.serializeOption(someValue)
        let bytes1 = s1.output()
        var d1 = Deserializer(data: bytes1)
        let result1: AccountAddress? = try d1.deserializeOption()
        XCTAssertEqual(result1, AccountAddress.ONE)
    }

    func testOptionRoundTripNone() throws {
        var s2 = Serializer()
        let noneValue: AccountAddress? = nil
        s2.serializeOption(noneValue)
        let bytes2 = s2.output()
        var d2 = Deserializer(data: bytes2)
        let result2: AccountAddress? = try d2.deserializeOption()
        XCTAssertNil(result2)
    }

    // MARK: - Signed Integers

    func testI8RoundTrip() throws {
        for value: Int8 in [Int8.min, -1, 0, 1, Int8.max] {
            var s = Serializer()
            s.serializeI8(value)
            let bytes = s.output()
            var d = Deserializer(data: bytes)
            let result = try d.deserializeI8()
            XCTAssertEqual(result, value, "I8 round-trip failed for \(value)")
        }
    }

    func testI16RoundTrip() throws {
        for value: Int16 in [Int16.min, -1, 0, 1, Int16.max] {
            var s = Serializer()
            s.serializeI16(value)
            let bytes = s.output()
            var d = Deserializer(data: bytes)
            let result = try d.deserializeI16()
            XCTAssertEqual(result, value, "I16 round-trip failed for \(value)")
        }
    }

    func testI32RoundTrip() throws {
        for value: Int32 in [Int32.min, -1, 0, 1, Int32.max] {
            var s = Serializer()
            s.serializeI32(value)
            let bytes = s.output()
            var d = Deserializer(data: bytes)
            let result = try d.deserializeI32()
            XCTAssertEqual(result, value, "I32 round-trip failed for \(value)")
        }
    }

    func testI64RoundTrip() throws {
        for value: Int64 in [Int64.min, -1, 0, 1, Int64.max] {
            var s = Serializer()
            s.serializeI64(value)
            let bytes = s.output()
            var d = Deserializer(data: bytes)
            let result = try d.deserializeI64()
            XCTAssertEqual(result, value, "I64 round-trip failed for \(value)")
        }
    }

    func testI128RoundTrip() throws {
        let values: [BigInt] = [
            -(BigInt(1) << 127),     // min
            BigInt(-1),
            BigInt(0),
            BigInt(1),
            (BigInt(1) << 127) - 1,  // max
        ]
        for value in values {
            var s = Serializer()
            s.serializeI128(value)
            let bytes = s.output()
            XCTAssertEqual(bytes.count, 16)
            var d = Deserializer(data: bytes)
            let result = try d.deserializeI128()
            XCTAssertEqual(result, value, "I128 round-trip failed for \(value)")
        }
    }

    func testI256RoundTrip() throws {
        let values: [BigInt] = [
            -(BigInt(1) << 255),     // min
            BigInt(-1),
            BigInt(0),
            BigInt(1),
            (BigInt(1) << 255) - 1,  // max
        ]
        for value in values {
            var s = Serializer()
            s.serializeI256(value)
            let bytes = s.output()
            XCTAssertEqual(bytes.count, 32)
            var d = Deserializer(data: bytes)
            let result = try d.deserializeI256()
            XCTAssertEqual(result, value, "I256 round-trip failed for \(value)")
        }
    }

    // MARK: - Serializable Protocol Conformances

    func testBoolSerializableConformance() throws {
        let bytes = true.bcsToBytes()
        XCTAssertEqual(bytes, Data([0x01]))
    }

    func testU8SerializableConformance() {
        let bytes = UInt8(42).bcsToBytes()
        XCTAssertEqual(bytes, Data([0x2A]))
    }

    func testU16SerializableConformance() {
        let bytes = UInt16(0x0100).bcsToBytes()
        XCTAssertEqual(bytes, Data([0x00, 0x01]))
    }

    func testU32SerializableConformance() {
        let bytes = UInt32(1).bcsToBytes()
        XCTAssertEqual(bytes, Data([0x01, 0x00, 0x00, 0x00]))
    }

    func testU64SerializableConformance() {
        let bytes = UInt64(1).bcsToBytes()
        XCTAssertEqual(bytes, Data([0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]))
    }

    func testStringSerializableConformance() {
        let bytes = "hi".bcsToBytes()
        // ULEB128(2) + "hi"
        XCTAssertEqual(bytes, Data([0x02, 0x68, 0x69]))
    }

    func testDataSerializableConformance() {
        let bytes = Data([0xAA, 0xBB]).bcsToBytes()
        // ULEB128(2) + payload
        XCTAssertEqual(bytes, Data([0x02, 0xAA, 0xBB]))
    }

    // MARK: - Multiple Serializations in Sequence

    func testMultipleSerializationsInOneSerializer() throws {
        var s = Serializer()
        s.serializeBool(true)
        s.serializeU8(42)
        s.serializeU16(1000)
        let bytes = s.output()
        // true=0x01, 42=0x2A, 1000=0xE803 LE
        XCTAssertEqual(bytes, Data([0x01, 0x2A, 0xE8, 0x03]))

        var d = Deserializer(data: bytes)
        XCTAssertEqual(try d.deserializeBool(), true)
        XCTAssertEqual(try d.deserializeU8(), 42)
        XCTAssertEqual(try d.deserializeU16(), 1000)
        try d.assertFinished()
    }

    // MARK: - bcsToHex

    func testBcsToHex() {
        let hex = UInt8(0xFF).bcsToHex()
        XCTAssertEqual(hex.toString(), "0xff")
    }
}
