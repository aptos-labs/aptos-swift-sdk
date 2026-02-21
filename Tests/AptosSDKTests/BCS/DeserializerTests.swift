import BigInt
import Foundation
import Testing
@testable import AptosSDK

@Suite("BCS Deserializer Tests")
struct DeserializerTests {
    @Test("Deserialize bool")
    func deserializeBool() throws {
        var d = Deserializer(data: Data([0x01]))
        let val = try d.deserializeBool()
        #expect(val == true)
        try d.assertFinished()
    }

    @Test("Deserialize u8")
    func deserializeU8() throws {
        var d = Deserializer(data: Data([0xFF]))
        let val = try d.deserializeU8()
        #expect(val == 255)
    }

    @Test("Deserialize u16")
    func deserializeU16() throws {
        var d = Deserializer(data: Data([0x02, 0x01]))
        let val = try d.deserializeU16()
        #expect(val == 0x0102)
    }

    @Test("Deserialize u32")
    func deserializeU32() throws {
        var d = Deserializer(data: Data([0x04, 0x03, 0x02, 0x01]))
        let val = try d.deserializeU32()
        #expect(val == 0x0102_0304)
    }

    @Test("Deserialize u64")
    func deserializeU64() throws {
        var d = Deserializer(data: Data([0x08, 0x07, 0x06, 0x05, 0x04, 0x03, 0x02, 0x01]))
        let val = try d.deserializeU64()
        #expect(val == 0x0102_0304_0506_0708)
    }

    @Test("Deserialize string")
    func deserializeStr() throws {
        var d = Deserializer(data: Data([0x05, 0x68, 0x65, 0x6C, 0x6C, 0x6F]))
        let val = try d.deserializeStr()
        #expect(val == "hello")
    }

    @Test("Deserialize ULEB128")
    func deserializeUleb128() throws {
        var d1 = Deserializer(data: Data([0x00]))
        #expect(try d1.deserializeUleb128() == 0)

        var d2 = Deserializer(data: Data([0x7F]))
        #expect(try d2.deserializeUleb128() == 127)

        var d3 = Deserializer(data: Data([0x80, 0x01]))
        #expect(try d3.deserializeUleb128() == 128)
    }

    @Test("Roundtrip bool")
    func roundtripBool() throws {
        let original = true
        let data = try bcsToBytes(original)
        let decoded = try bcsFromBytes(Bool.self, data)
        #expect(decoded == original)
    }

    @Test("Roundtrip u64")
    func roundtripU64() throws {
        let original: UInt64 = 12_345_678
        let data = try bcsToBytes(original)
        let decoded = try bcsFromBytes(UInt64.self, data)
        #expect(decoded == original)
    }

    @Test("Roundtrip string")
    func roundtripString() throws {
        let original = "Hello, Aptos!"
        let data = try bcsToBytes(original)
        let decoded = try bcsFromBytes(String.self, data)
        #expect(decoded == original)
    }

    @Test("Error on unexpected end")
    func unexpectedEnd() throws {
        var d = Deserializer(data: Data([0x01]))
        _ = try d.deserializeU8()
        #expect(throws: AptosError.self) {
            try d.deserializeU8()
        }
    }

    @Test("Error on remaining bytes")
    func remainingBytes() throws {
        let d = Deserializer(data: Data([0x01, 0x02]))
        #expect(throws: AptosError.self) {
            try d.assertFinished()
        }
    }

    @Test("Deserialize signed integers")
    func deserializeSignedIntegers() throws {
        var d1 = Deserializer(data: Data([0xFF]))
        #expect(try d1.deserializeI8() == -1)

        var d2 = Deserializer(data: Data([0xFF, 0xFF]))
        #expect(try d2.deserializeI16() == -1)

        var d3 = Deserializer(data: Data([0xFF, 0xFF, 0xFF, 0xFF]))
        #expect(try d3.deserializeI32() == -1)

        var d4 = Deserializer(data: Data([0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]))
        #expect(try d4.deserializeI64() == -1)
    }

    // MARK: - i256

    @Test("Deserialize i256 zero")
    func deserializeI256Zero() throws {
        var d = Deserializer(data: Data(repeating: 0, count: 32))
        let val = try d.deserializeI256()
        #expect(val == BigInt(0))
    }

    @Test("Deserialize i256 positive")
    func deserializeI256Positive() throws {
        var input = Data(repeating: 0, count: 32)
        input[0] = 0x01
        var d = Deserializer(data: input)
        let val = try d.deserializeI256()
        #expect(val == BigInt(1))
    }

    @Test("Deserialize i256 negative one")
    func deserializeI256NegativeOne() throws {
        var d = Deserializer(data: Data(repeating: 0xFF, count: 32))
        let val = try d.deserializeI256()
        #expect(val == BigInt(-1))
    }

    @Test("i256 roundtrip positive")
    func i256RoundtripPositive() throws {
        let original = BigInt(123_456_789)
        var s = Serializer()
        try s.serializeI256(original)
        var d = Deserializer(data: s.toBytes())
        let decoded = try d.deserializeI256()
        #expect(decoded == original)
    }

    @Test("i256 roundtrip negative")
    func i256RoundtripNegative() throws {
        let original = BigInt(-987_654_321)
        var s = Serializer()
        try s.serializeI256(original)
        var d = Deserializer(data: s.toBytes())
        let decoded = try d.deserializeI256()
        #expect(decoded == original)
    }

    @Test("i256 roundtrip max value")
    func i256RoundtripMax() throws {
        let maxI256 = (BigInt(1) << 255) - 1
        var s = Serializer()
        try s.serializeI256(maxI256)
        var d = Deserializer(data: s.toBytes())
        let decoded = try d.deserializeI256()
        #expect(decoded == maxI256)
    }

    @Test("i256 roundtrip min value")
    func i256RoundtripMin() throws {
        let minI256 = -(BigInt(1) << 255)
        var s = Serializer()
        try s.serializeI256(minI256)
        var d = Deserializer(data: s.toBytes())
        let decoded = try d.deserializeI256()
        #expect(decoded == minI256)
    }
}
