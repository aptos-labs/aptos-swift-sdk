import Foundation
import Testing
@testable import AptosSDK

@Suite("BCS Serializer Tests")
struct SerializerTests {
    @Test("Serialize bool")
    func serializeBool() {
        var s = Serializer()
        s.serializeBool(true)
        let bytes = s.toBytes()
        #expect(bytes == Data([0x01]))

        var s2 = Serializer()
        s2.serializeBool(false)
        let bytes2 = s2.toBytes()
        #expect(bytes2 == Data([0x00]))
    }

    @Test("Serialize u8")
    func serializeU8() {
        var s = Serializer()
        s.serializeU8(255)
        let bytes = s.toBytes()
        #expect(bytes == Data([0xFF]))
    }

    @Test("Serialize u16")
    func serializeU16() {
        var s = Serializer()
        s.serializeU16(0x0102)
        let bytes = s.toBytes()
        #expect(bytes == Data([0x02, 0x01])) // Little-endian
    }

    @Test("Serialize u32")
    func serializeU32() {
        var s = Serializer()
        s.serializeU32(0x0102_0304)
        let bytes = s.toBytes()
        #expect(bytes == Data([0x04, 0x03, 0x02, 0x01]))
    }

    @Test("Serialize u64")
    func serializeU64() {
        var s = Serializer()
        s.serializeU64(0x0102_0304_0506_0708)
        let bytes = s.toBytes()
        #expect(bytes == Data([0x08, 0x07, 0x06, 0x05, 0x04, 0x03, 0x02, 0x01]))
    }

    @Test("Serialize string")
    func serializeStr() throws {
        var s = Serializer()
        try s.serializeStr("hello")
        let bytes = s.toBytes()
        // ULEB128(5) = 0x05, then "hello" bytes
        #expect(bytes == Data([0x05, 0x68, 0x65, 0x6C, 0x6C, 0x6F]))
    }

    @Test("Serialize empty string")
    func serializeEmptyStr() throws {
        var s = Serializer()
        try s.serializeStr("")
        let bytes = s.toBytes()
        #expect(bytes == Data([0x00]))
    }

    @Test("Serialize bytes with length prefix")
    func serializeBytes() throws {
        var s = Serializer()
        try s.serializeBytes([1, 2, 3])
        let bytes = s.toBytes()
        #expect(bytes == Data([0x03, 0x01, 0x02, 0x03]))
    }

    @Test("Serialize fixed bytes without prefix")
    func serializeFixedBytes() {
        var s = Serializer()
        s.serializeFixedBytes([0xAB, 0xCD])
        let bytes = s.toBytes()
        #expect(bytes == Data([0xAB, 0xCD]))
    }

    @Test("Serialize ULEB128")
    func serializeUleb128() throws {
        // 0 -> 0x00
        var s1 = Serializer()
        try s1.serializeU32AsUleb128(0)
        #expect(s1.toBytes() == Data([0x00]))

        // 127 -> 0x7F
        var s2 = Serializer()
        try s2.serializeU32AsUleb128(127)
        #expect(s2.toBytes() == Data([0x7F]))

        // 128 -> 0x80 0x01
        var s3 = Serializer()
        try s3.serializeU32AsUleb128(128)
        #expect(s3.toBytes() == Data([0x80, 0x01]))
    }

    @Test("Serialize signed integers")
    func serializeSignedIntegers() {
        var s = Serializer()
        s.serializeI8(-1)
        #expect(s.toBytes() == Data([0xFF]))

        var s2 = Serializer()
        s2.serializeI16(-1)
        #expect(s2.toBytes() == Data([0xFF, 0xFF]))

        var s3 = Serializer()
        s3.serializeI32(-1)
        #expect(s3.toBytes() == Data([0xFF, 0xFF, 0xFF, 0xFF]))

        var s4 = Serializer()
        s4.serializeI64(-1)
        #expect(s4.toBytes() == Data([0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]))
    }

    @Test("Multiple serializations to same serializer")
    func multipleSerializations() {
        var s = Serializer()
        s.serializeBool(true)
        s.serializeU8(42)
        s.serializeU32(100)
        let bytes = s.toBytes()
        #expect(bytes == Data([0x01, 0x2A, 0x64, 0x00, 0x00, 0x00]))
    }
}
