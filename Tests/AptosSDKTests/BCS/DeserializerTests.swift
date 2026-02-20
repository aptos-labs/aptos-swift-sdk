import BigInt
import Foundation
import XCTest

@testable import AptosSDK

final class DeserializerTests: XCTestCase {

    // MARK: - Bool

    func testDeserializeBoolTrue() throws {
        var d = Deserializer(data: Data([0x01]))
        XCTAssertEqual(try d.deserializeBool(), true)
    }

    func testDeserializeBoolFalse() throws {
        var d = Deserializer(data: Data([0x00]))
        XCTAssertEqual(try d.deserializeBool(), false)
    }

    func testDeserializeBoolInvalidValue() {
        var d = Deserializer(data: Data([0x02]))
        XCTAssertThrowsError(try d.deserializeBool()) { error in
            guard case AptosError.deserializationError(let msg) = error else {
                XCTFail("Expected deserializationError, got: \(error)")
                return
            }
            XCTAssertTrue(msg.contains("Invalid bool value"))
        }
    }

    // MARK: - U8

    func testDeserializeU8() throws {
        var d = Deserializer(data: Data([0xFF]))
        XCTAssertEqual(try d.deserializeU8(), 255)
    }

    func testDeserializeU8EmptyData() {
        var d = Deserializer(data: Data())
        XCTAssertThrowsError(try d.deserializeU8()) { error in
            guard case AptosError.deserializationError(let msg) = error else {
                XCTFail("Expected deserializationError, got: \(error)")
                return
            }
            XCTAssertTrue(msg.contains("Not enough bytes"))
        }
    }

    // MARK: - U16

    func testDeserializeU16KnownBytes() throws {
        // 0x0100 in LE = [0x00, 0x01]
        var d = Deserializer(data: Data([0x00, 0x01]))
        XCTAssertEqual(try d.deserializeU16(), 256)
    }

    func testDeserializeU16InsufficientBytes() {
        var d = Deserializer(data: Data([0x01]))
        XCTAssertThrowsError(try d.deserializeU16())
    }

    // MARK: - U32

    func testDeserializeU32KnownBytes() throws {
        var d = Deserializer(data: Data([0x04, 0x03, 0x02, 0x01]))
        XCTAssertEqual(try d.deserializeU32(), 0x01020304)
    }

    func testDeserializeU32MaxValue() throws {
        var d = Deserializer(data: Data([0xFF, 0xFF, 0xFF, 0xFF]))
        XCTAssertEqual(try d.deserializeU32(), UInt32.max)
    }

    // MARK: - U64

    func testDeserializeU64KnownBytes() throws {
        var d = Deserializer(data: Data([0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]))
        XCTAssertEqual(try d.deserializeU64(), 1)
    }

    func testDeserializeU64MaxValue() throws {
        var d = Deserializer(data: Data(repeating: 0xFF, count: 8))
        XCTAssertEqual(try d.deserializeU64(), UInt64.max)
    }

    // MARK: - U128

    func testDeserializeU128Zero() throws {
        var d = Deserializer(data: Data(repeating: 0, count: 16))
        let result = try d.deserializeU128()
        XCTAssertEqual(result, BigUInt(0))
    }

    func testDeserializeU128One() throws {
        var bytes = Data(repeating: 0, count: 16)
        bytes[0] = 0x01  // LE: first byte = 1
        var d = Deserializer(data: bytes)
        let result = try d.deserializeU128()
        XCTAssertEqual(result, BigUInt(1))
    }

    func testDeserializeU128Max() throws {
        var d = Deserializer(data: Data(repeating: 0xFF, count: 16))
        let result = try d.deserializeU128()
        XCTAssertEqual(result, (BigUInt(1) << 128) - 1)
    }

    func testDeserializeU128InsufficientBytes() {
        var d = Deserializer(data: Data(repeating: 0, count: 10))
        XCTAssertThrowsError(try d.deserializeU128())
    }

    // MARK: - U256

    func testDeserializeU256Zero() throws {
        var d = Deserializer(data: Data(repeating: 0, count: 32))
        let result = try d.deserializeU256()
        XCTAssertEqual(result, BigUInt(0))
    }

    func testDeserializeU256Max() throws {
        var d = Deserializer(data: Data(repeating: 0xFF, count: 32))
        let result = try d.deserializeU256()
        XCTAssertEqual(result, (BigUInt(1) << 256) - 1)
    }

    // MARK: - I8

    func testDeserializeI8Negative() throws {
        // -1 in two's complement 1 byte = 0xFF
        var d = Deserializer(data: Data([0xFF]))
        XCTAssertEqual(try d.deserializeI8(), -1)
    }

    func testDeserializeI8Min() throws {
        // Int8.min = -128 = 0x80
        var d = Deserializer(data: Data([0x80]))
        XCTAssertEqual(try d.deserializeI8(), Int8.min)
    }

    // MARK: - I128

    func testDeserializeI128Negative() throws {
        // -1 in two's complement 16 bytes = all 0xFF
        var d = Deserializer(data: Data(repeating: 0xFF, count: 16))
        let result = try d.deserializeI128()
        XCTAssertEqual(result, BigInt(-1))
    }

    func testDeserializeI128Min() throws {
        // Min i128 = -(2^127)
        // In LE: [0x00, 0x00, ..., 0x00, 0x80] (last byte in LE is highest byte = 0x80)
        var bytes = Data(repeating: 0, count: 16)
        bytes[15] = 0x80
        var d = Deserializer(data: bytes)
        let result = try d.deserializeI128()
        XCTAssertEqual(result, -(BigInt(1) << 127))
    }

    // MARK: - Str

    func testDeserializeStr() throws {
        // ULEB128(5) = 0x05, then "hello"
        let data = Data([0x05]) + Data("hello".utf8)
        var d = Deserializer(data: data)
        XCTAssertEqual(try d.deserializeStr(), "hello")
    }

    func testDeserializeStrEmpty() throws {
        var d = Deserializer(data: Data([0x00]))
        XCTAssertEqual(try d.deserializeStr(), "")
    }

    func testDeserializeStrInsufficientBytes() {
        // Says length is 5 but only 2 bytes follow
        let data = Data([0x05, 0x68, 0x69])
        var d = Deserializer(data: data)
        XCTAssertThrowsError(try d.deserializeStr())
    }

    // MARK: - Bytes

    func testDeserializeBytes() throws {
        let data = Data([0x03, 0xAA, 0xBB, 0xCC])
        var d = Deserializer(data: data)
        let result = try d.deserializeBytes()
        XCTAssertEqual(result, Data([0xAA, 0xBB, 0xCC]))
    }

    func testDeserializeBytesEmpty() throws {
        var d = Deserializer(data: Data([0x00]))
        let result = try d.deserializeBytes()
        XCTAssertEqual(result, Data())
    }

    // MARK: - Fixed Bytes

    func testDeserializeFixedBytes() throws {
        let data = Data([0xAB, 0xCD, 0xEF])
        var d = Deserializer(data: data)
        let result = try d.deserializeFixedBytes(3)
        XCTAssertEqual(result, Data([0xAB, 0xCD, 0xEF]))
    }

    func testDeserializeFixedBytesInsufficientData() {
        var d = Deserializer(data: Data([0xAB]))
        XCTAssertThrowsError(try d.deserializeFixedBytes(3))
    }

    // MARK: - ULEB128

    func testDeserializeUleb128Zero() throws {
        var d = Deserializer(data: Data([0x00]))
        XCTAssertEqual(try d.deserializeUleb128(), 0)
    }

    func testDeserializeUleb128SingleByte() throws {
        var d = Deserializer(data: Data([0x7F]))
        XCTAssertEqual(try d.deserializeUleb128(), 127)
    }

    func testDeserializeUleb128TwoBytes() throws {
        var d = Deserializer(data: Data([0x80, 0x01]))
        XCTAssertEqual(try d.deserializeUleb128(), 128)
    }

    func testDeserializeUleb128ThreeHundred() throws {
        var d = Deserializer(data: Data([0xAC, 0x02]))
        XCTAssertEqual(try d.deserializeUleb128(), 300)
    }

    func testDeserializeUleb128Empty() {
        var d = Deserializer(data: Data())
        XCTAssertThrowsError(try d.deserializeUleb128())
    }

    // MARK: - Vector (using AccountAddress which conforms to Deserializable)

    func testDeserializeVectorAccountAddress() throws {
        // Serialize a vector of 2 AccountAddresses
        var s = Serializer()
        s.serializeVector([AccountAddress.ZERO, AccountAddress.ONE])
        let serialized = s.output()
        var d = Deserializer(data: serialized)
        let result: [AccountAddress] = try d.deserializeVector()
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0], AccountAddress.ZERO)
        XCTAssertEqual(result[1], AccountAddress.ONE)
    }

    func testDeserializeVectorEmpty() throws {
        var d = Deserializer(data: Data([0x00]))
        let result: [AccountAddress] = try d.deserializeVector()
        XCTAssertEqual(result, [])
    }

    // MARK: - Option (using AccountAddress which conforms to Deserializable)

    func testDeserializeOptionSome() throws {
        var s = Serializer()
        let addr: AccountAddress? = AccountAddress.ONE
        s.serializeOption(addr)
        let bytes = s.output()
        var d = Deserializer(data: bytes)
        let result: AccountAddress? = try d.deserializeOption()
        XCTAssertEqual(result, AccountAddress.ONE)
    }

    func testDeserializeOptionNone() throws {
        var s = Serializer()
        let addr: AccountAddress? = nil
        s.serializeOption(addr)
        let bytes = s.output()
        var d = Deserializer(data: bytes)
        let result: AccountAddress? = try d.deserializeOption()
        XCTAssertNil(result)
    }

    // MARK: - State Management

    func testRemaining() throws {
        var d = Deserializer(data: Data([0x01, 0x02, 0x03]))
        XCTAssertEqual(d.remaining, 3)
        _ = try d.deserializeU8()
        XCTAssertEqual(d.remaining, 2)
        _ = try d.deserializeU8()
        XCTAssertEqual(d.remaining, 1)
        _ = try d.deserializeU8()
        XCTAssertEqual(d.remaining, 0)
    }

    func testAssertFinishedSuccess() throws {
        var d = Deserializer(data: Data([0x01]))
        _ = try d.deserializeU8()
        try d.assertFinished()
    }

    func testAssertFinishedFailsWithRemainingBytes() throws {
        var d = Deserializer(data: Data([0x01, 0x02]))
        _ = try d.deserializeU8()
        XCTAssertThrowsError(try d.assertFinished()) { error in
            guard case AptosError.deserializationError(let msg) = error else {
                XCTFail("Expected deserializationError, got: \(error)")
                return
            }
            XCTAssertTrue(msg.contains("1 bytes remaining"))
        }
    }

    // MARK: - Edge Cases

    func testDeserializeFromEmptyData() {
        var d = Deserializer(data: Data())
        XCTAssertThrowsError(try d.deserializeBool())
        var d2 = Deserializer(data: Data())
        XCTAssertThrowsError(try d2.deserializeU16())
        var d3 = Deserializer(data: Data())
        XCTAssertThrowsError(try d3.deserializeU32())
        var d4 = Deserializer(data: Data())
        XCTAssertThrowsError(try d4.deserializeU64())
    }

    func testDeserializeMultipleValuesSequentially() throws {
        // Serialize: bool(true) + u8(42) + u16(1000)
        let data = Data([0x01, 0x2A, 0xE8, 0x03])
        var d = Deserializer(data: data)
        XCTAssertEqual(try d.deserializeBool(), true)
        XCTAssertEqual(try d.deserializeU8(), 42)
        XCTAssertEqual(try d.deserializeU16(), 1000)
        try d.assertFinished()
    }

    // MARK: - Deserializable Conformances (AccountAddress)

    func testAccountAddressDeserializable() throws {
        let bytes = AccountAddress.ONE.bcsToBytes()
        var d = Deserializer(data: bytes)
        let value = try AccountAddress.deserialize(from: &d)
        XCTAssertEqual(value, AccountAddress.ONE)
        try d.assertFinished()
    }

    func testEd25519PublicKeyDeserializable() throws {
        let privateKey = Ed25519PrivateKey.generate()
        let pk = privateKey.publicKey()
        let serialized = pk.bcsToBytes()
        var d = Deserializer(data: serialized)
        let deserialized = try Ed25519PublicKey.deserialize(from: &d)
        XCTAssertEqual(deserialized.data, pk.data)
        try d.assertFinished()
    }
}
