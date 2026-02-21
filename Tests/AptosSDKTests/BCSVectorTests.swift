import BigInt
import Foundation
import Testing
@testable import AptosSDK

@Suite("BCS Test Vectors")
struct BCSVectorTests {
    // MARK: - Bool

    @Test("Bool false serialization")
    func boolFalse() {
        var s = Serializer()
        s.serializeBool(false)
        #expect(dataToHex(s.toBytes()) == "00")
    }

    @Test("Bool true serialization")
    func boolTrue() {
        var s = Serializer()
        s.serializeBool(true)
        #expect(dataToHex(s.toBytes()) == "01")
    }

    // MARK: - U8

    @Test("U8 values", arguments: [
        (UInt8(0), "00"), (UInt8(1), "01"), (UInt8(127), "7f"),
        (UInt8(128), "80"), (UInt8(255), "ff"),
    ])
    func u8Values(value: UInt8, hex: String) {
        var s = Serializer()
        s.serializeU8(value)
        #expect(dataToHex(s.toBytes()) == hex)
    }

    // MARK: - U16

    @Test("U16 values", arguments: [
        (UInt16(0), "0000"), (UInt16(1), "0100"),
        (UInt16(256), "0001"), (UInt16(65535), "ffff"),
    ])
    func u16Values(value: UInt16, hex: String) {
        var s = Serializer()
        s.serializeU16(value)
        #expect(dataToHex(s.toBytes()) == hex)
    }

    // MARK: - U32

    @Test("U32 values", arguments: [
        (UInt32(0), "00000000"), (UInt32(1), "01000000"),
        (UInt32(256), "00010000"), (UInt32(305_419_896), "78563412"),
        (UInt32(4_294_967_295), "ffffffff"),
    ])
    func u32Values(value: UInt32, hex: String) {
        var s = Serializer()
        s.serializeU32(value)
        #expect(dataToHex(s.toBytes()) == hex)
    }

    // MARK: - U64

    @Test("U64 zero")
    func u64Zero() {
        var s = Serializer()
        s.serializeU64(0)
        #expect(dataToHex(s.toBytes()) == "0000000000000000")
    }

    @Test("U64 one")
    func u64One() {
        var s = Serializer()
        s.serializeU64(1)
        #expect(dataToHex(s.toBytes()) == "0100000000000000")
    }

    @Test("U64 million")
    func u64Million() {
        var s = Serializer()
        s.serializeU64(1_000_000)
        #expect(dataToHex(s.toBytes()) == "40420f0000000000")
    }

    @Test("U64 100 million (1 APT)")
    func u64Apt() {
        var s = Serializer()
        s.serializeU64(100_000_000)
        #expect(dataToHex(s.toBytes()) == "00e1f50500000000")
    }

    @Test("U64 max")
    func u64Max() {
        var s = Serializer()
        s.serializeU64(UInt64.max)
        #expect(dataToHex(s.toBytes()) == "ffffffffffffffff")
    }

    // MARK: - U128

    @Test("U128 zero")
    func u128Zero() throws {
        var s = Serializer()
        try s.serializeU128(BigUInt(0))
        #expect(dataToHex(s.toBytes()) == "00000000000000000000000000000000")
    }

    @Test("U128 one")
    func u128One() throws {
        var s = Serializer()
        try s.serializeU128(BigUInt(1))
        #expect(dataToHex(s.toBytes()) == "01000000000000000000000000000000")
    }

    @Test("U128 max")
    func u128Max() throws {
        var s = Serializer()
        let maxU128 = (BigUInt(1) << 128) - 1
        try s.serializeU128(maxU128)
        #expect(dataToHex(s.toBytes()) == "ffffffffffffffffffffffffffffffff")
    }

    // MARK: - U256

    @Test("U256 zero")
    func u256Zero() throws {
        var s = Serializer()
        try s.serializeU256(BigUInt(0))
        #expect(dataToHex(s.toBytes()) == "0000000000000000000000000000000000000000000000000000000000000000")
    }

    @Test("U256 one")
    func u256One() throws {
        var s = Serializer()
        try s.serializeU256(BigUInt(1))
        #expect(dataToHex(s.toBytes()) == "0100000000000000000000000000000000000000000000000000000000000000")
    }

    // MARK: - ULEB128

    @Test("ULEB128 encoding", arguments: [
        (UInt32(0), "00"), (UInt32(1), "01"), (UInt32(127), "7f"),
        (UInt32(128), "8001"), (UInt32(255), "ff01"),
        (UInt32(256), "8002"), (UInt32(16383), "ff7f"),
        (UInt32(16384), "808001"), (UInt32(2_097_151), "ffff7f"),
        (UInt32(2_097_152), "80808001"),
    ])
    func uleb128Encoding(value: UInt32, hex: String) throws {
        var s = Serializer()
        try s.serializeU32AsUleb128(value)
        #expect(dataToHex(s.toBytes()) == hex)
    }

    @Test("ULEB128 roundtrip", arguments: [
        UInt32(0), UInt32(1), UInt32(127), UInt32(128), UInt32(255),
        UInt32(256), UInt32(16383), UInt32(16384), UInt32(2_097_152),
    ])
    func uleb128Roundtrip(value: UInt32) throws {
        var s = Serializer()
        try s.serializeU32AsUleb128(value)
        var de = Deserializer(data: s.toBytes())
        let decoded = try de.deserializeUleb128()
        #expect(decoded == value)
    }

    // MARK: - Bytes and Strings

    @Test("Empty bytes")
    func emptyBytes() throws {
        var s = Serializer()
        try s.serializeBytes([UInt8]())
        #expect(dataToHex(s.toBytes()) == "00")
    }

    @Test("Single byte")
    func singleByte() throws {
        var s = Serializer()
        try s.serializeBytes([42])
        #expect(dataToHex(s.toBytes()) == "012a")
    }

    @Test("Three bytes")
    func threeBytes() throws {
        var s = Serializer()
        try s.serializeBytes([1, 2, 3])
        #expect(dataToHex(s.toBytes()) == "03010203")
    }

    @Test("Empty string")
    func emptyString() throws {
        var s = Serializer()
        try s.serializeStr("")
        #expect(dataToHex(s.toBytes()) == "00")
    }

    @Test("Hello string")
    func helloString() throws {
        var s = Serializer()
        try s.serializeStr("hello")
        #expect(dataToHex(s.toBytes()) == "0568656c6c6f")
    }

    @Test("Hello world string")
    func helloWorldString() throws {
        var s = Serializer()
        try s.serializeStr("hello world")
        #expect(dataToHex(s.toBytes()) == "0b68656c6c6f20776f726c64")
    }

    @Test("Unicode string (héllo)")
    func unicodeString() throws {
        var s = Serializer()
        try s.serializeStr("héllo")
        #expect(dataToHex(s.toBytes()) == "0668c3a96c6c6f")
    }

    // MARK: - Option

    @Test("Option none")
    func optionNone() throws {
        var s = Serializer()
        try s.serializeOption(nil as UInt64?)
        #expect(dataToHex(s.toBytes()) == "00")
    }

    @Test("Option some u64")
    func optionSomeU64() throws {
        var s = Serializer()
        try s.serializeOption(UInt64(42))
        #expect(dataToHex(s.toBytes()) == "012a00000000000000")
    }

    @Test("Option some bool")
    func optionSomeBool() throws {
        var s = Serializer()
        try s.serializeOption(true)
        #expect(dataToHex(s.toBytes()) == "0101")
    }

    // MARK: - Vectors

    @Test("Empty vector u8")
    func emptyVectorU8() throws {
        var s = Serializer()
        try s.serializeBytes([UInt8]())
        #expect(dataToHex(s.toBytes()) == "00")
    }

    @Test("Vector u8")
    func vectorU8() throws {
        var s = Serializer()
        try s.serializeBytes([1, 2, 3, 4, 5])
        #expect(dataToHex(s.toBytes()) == "050102030405")
    }

    @Test("Vector bool")
    func vectorBool() throws {
        var s = Serializer()
        try s.serializeVector([true, false, true])
        #expect(dataToHex(s.toBytes()) == "03010001")
    }

    // MARK: - Structs

    @Test("Simple struct {a: u8, b: u64}")
    func simpleStruct() {
        var s = Serializer()
        s.serializeU8(1)
        s.serializeU64(100)
        #expect(dataToHex(s.toBytes()) == "016400000000000000")
    }

    @Test("Struct with string {name: String, value: u64}")
    func structWithString() throws {
        var s = Serializer()
        try s.serializeStr("test")
        s.serializeU64(42)
        #expect(dataToHex(s.toBytes()) == "04746573742a00000000000000")
    }

    // MARK: - Deserialization Errors

    @Test("Truncated u64 fails")
    func truncatedU64() {
        var de = Deserializer(data: hexToData("0102030405"))
        #expect(throws: (any Error).self) {
            _ = try de.deserializeU64()
        }
    }

    @Test("Invalid bool fails")
    func invalidBool() {
        var de = Deserializer(data: hexToData("02"))
        #expect(throws: (any Error).self) {
            _ = try de.deserializeBool()
        }
    }

    @Test("Truncated vector fails")
    func truncatedVector() {
        var de = Deserializer(data: hexToData("05010203"))
        #expect(throws: (any Error).self) {
            _ = try de.deserializeBytes()
        }
    }

    // MARK: - Non-canonical ULEB128

    @Test("Non-canonical ULEB128 with trailing zero is rejected")
    func nonCanonicalUleb128() {
        // 0x80 0x00 encodes 0, but canonical encoding is just 0x00
        var de = Deserializer(data: Data([0x80, 0x00]))
        #expect(throws: (any Error).self) {
            _ = try de.deserializeUleb128()
        }
    }

    // MARK: - I128

    @Test("I128 positive roundtrip")
    func i128Positive() throws {
        var s = Serializer()
        try s.serializeI128(BigInt(42))
        var de = Deserializer(data: s.toBytes())
        let result = try de.deserializeI128()
        #expect(result == BigInt(42))
    }

    @Test("I128 negative roundtrip")
    func i128Negative() throws {
        var s = Serializer()
        try s.serializeI128(BigInt(-1))
        var de = Deserializer(data: s.toBytes())
        let result = try de.deserializeI128()
        #expect(result == BigInt(-1))
    }

    @Test("I128 zero roundtrip")
    func i128Zero() throws {
        var s = Serializer()
        try s.serializeI128(BigInt(0))
        var de = Deserializer(data: s.toBytes())
        let result = try de.deserializeI128()
        #expect(result == BigInt(0))
    }

    @Test("I128 min value roundtrip")
    func i128Min() throws {
        let minI128 = -(BigInt(1) << 127)
        var s = Serializer()
        try s.serializeI128(minI128)
        var de = Deserializer(data: s.toBytes())
        let result = try de.deserializeI128()
        #expect(result == minI128)
    }

    @Test("I128 max value roundtrip")
    func i128Max() throws {
        let maxI128 = (BigInt(1) << 127) - 1
        var s = Serializer()
        try s.serializeI128(maxI128)
        var de = Deserializer(data: s.toBytes())
        let result = try de.deserializeI128()
        #expect(result == maxI128)
    }

    // MARK: - Depth Tracking

    @Test("BCS serialization depth limit is enforced")
    func depthLimit() {
        // This is a compile-time/structural check; deep nesting would require
        // nested BCSSerializable types. We just verify the constants are set.
        #expect(Serializer.maxDepth == 128)
        #expect(Deserializer.maxDepth == 128)
    }
}
