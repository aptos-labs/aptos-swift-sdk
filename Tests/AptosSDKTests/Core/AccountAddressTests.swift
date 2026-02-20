import Foundation
import XCTest

@testable import AptosSDK

final class AccountAddressTests: XCTestCase {

    // MARK: - Parsing from Hex String

    func testFromStringWith0xPrefix() throws {
        let addr = try AccountAddress.fromString("0x1")
        XCTAssertEqual(addr, AccountAddress.ONE)
    }

    func testFromStringWithout0xPrefix() throws {
        let addr = try AccountAddress.fromString("1")
        XCTAssertEqual(addr, AccountAddress.ONE)
    }

    func testFromStringWith0XUppercasePrefix() throws {
        let addr = try AccountAddress.fromString("0X1")
        XCTAssertEqual(addr, AccountAddress.ONE)
    }

    func testFromStringLongFormHex() throws {
        let longHex = "0x" + String(repeating: "0", count: 63) + "1"
        let addr = try AccountAddress.fromString(longHex)
        XCTAssertEqual(addr, AccountAddress.ONE)
    }

    func testFromStringFullLengthWithoutPadding() throws {
        let fullHex = String(repeating: "0", count: 63) + "1"
        let addr = try AccountAddress.fromString(fullHex)
        XCTAssertEqual(addr, AccountAddress.ONE)
    }

    func testFromStringTooLong() {
        // 65 hex chars (exceeds 64)
        let longHex = "0x" + String(repeating: "a", count: 65)
        XCTAssertThrowsError(try AccountAddress.fromString(longHex)) { error in
            guard case AptosError.invalidArgument(let msg) = error else {
                XCTFail("Expected invalidArgument, got: \(error)")
                return
            }
            XCTAssertTrue(msg.contains("too long"))
        }
    }

    func testFromStringInvalidHexCharacters() {
        XCTAssertThrowsError(try AccountAddress.fromString("0xGHIJ")) { error in
            guard case AptosError.invalidArgument(let msg) = error else {
                XCTFail("Expected invalidArgument, got: \(error)")
                return
            }
            XCTAssertTrue(msg.contains("invalid hex"))
        }
    }

    // MARK: - Short Form vs Long Form

    func testShortFormForSpecialAddresses() {
        XCTAssertEqual(AccountAddress.ZERO.toStringShort(), "0x0")
        XCTAssertEqual(AccountAddress.ONE.toStringShort(), "0x1")
        XCTAssertEqual(AccountAddress.THREE.toStringShort(), "0x3")
        XCTAssertEqual(AccountAddress.FOUR.toStringShort(), "0x4")
    }

    func testShortFormForNonSpecialAddressUsesLongForm() throws {
        // Address 0x10 is NOT special (last byte = 0x10 > 0x0F)
        let addr = try AccountAddress.fromString("0x10")
        XCTAssertEqual(addr.toStringShort(), addr.toStringLong())
    }

    func testLongFormForSpecialAddresses() {
        let longZero = "0x" + String(repeating: "0", count: 64)
        XCTAssertEqual(AccountAddress.ZERO.toStringLong(), longZero)

        let longOne = "0x" + String(repeating: "0", count: 63) + "1"
        XCTAssertEqual(AccountAddress.ONE.toStringLong(), longOne)
    }

    func testToStringReturnsLongForm() {
        XCTAssertEqual(AccountAddress.ONE.toString(), AccountAddress.ONE.toStringLong())
    }

    func testDescriptionReturnsShortForm() {
        // CustomStringConvertible uses toStringShort
        XCTAssertEqual(AccountAddress.ONE.description, "0x1")
    }

    // MARK: - Short Form for All Single-Hex-Digit Addresses

    func testAllSingleDigitAddresses() throws {
        for i: UInt8 in 0...0x0F {
            let addr = try AccountAddress.fromString("0x\(String(format: "%x", i))")
            XCTAssertTrue(addr.isSpecial, "Address 0x\(String(format: "%x", i)) should be special")
            XCTAssertEqual(addr.toStringShort(), "0x\(String(format: "%x", i))")
        }
    }

    // MARK: - Padding from Short Hex

    func testFromStringPadsShortHex() throws {
        let addr = try AccountAddress.fromString("0xabc")
        XCTAssertEqual(addr.data.count, 32)
        // Should be padded with zeros on the left
        let expectedHex = "0x" + String(repeating: "0", count: 61) + "abc"
        XCTAssertEqual(addr.toStringLong(), expectedHex)
    }

    func testFromStringPadsSingleDigit() throws {
        let addr = try AccountAddress.fromString("0xf")
        XCTAssertEqual(addr.data.count, 32)
        let expectedHex = "0x" + String(repeating: "0", count: 63) + "f"
        XCTAssertEqual(addr.toStringLong(), expectedHex)
    }

    // MARK: - BCS Serialization Round-trip

    func testBcsSerializationIsFixed32Bytes() {
        let bytes = AccountAddress.ONE.bcsToBytes()
        // AccountAddress serializes as fixed bytes (no length prefix)
        XCTAssertEqual(bytes.count, 32)
    }

    func testBcsSerializationNoLengthPrefix() {
        // The first byte should NOT be a ULEB128 length; it should be the first data byte
        let bytes = AccountAddress.ONE.bcsToBytes()
        // For address 0x1, first 31 bytes are 0, last byte is 1
        XCTAssertEqual(bytes[0], 0x00)
        XCTAssertEqual(bytes[31], 0x01)
    }

    func testBcsRoundTripZero() throws {
        let original = AccountAddress.ZERO
        let bytes = original.bcsToBytes()
        var d = Deserializer(data: bytes)
        let decoded = try AccountAddress.deserialize(from: &d)
        XCTAssertEqual(decoded, original)
        try d.assertFinished()
    }

    func testBcsRoundTripOne() throws {
        let original = AccountAddress.ONE
        let bytes = original.bcsToBytes()
        var d = Deserializer(data: bytes)
        let decoded = try AccountAddress.deserialize(from: &d)
        XCTAssertEqual(decoded, original)
    }

    func testBcsRoundTripArbitrary() throws {
        let hexStr = "0x" + String(repeating: "ab", count: 32)
        let original = try AccountAddress.fromString(hexStr)
        let bytes = original.bcsToBytes()
        XCTAssertEqual(bytes.count, 32)

        var d = Deserializer(data: bytes)
        let decoded = try AccountAddress.deserialize(from: &d)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - Constants

    func testConstantZero() {
        XCTAssertEqual(AccountAddress.ZERO.data, Data(repeating: 0, count: 32))
    }

    func testConstantOne() {
        var expected = Data(repeating: 0, count: 32)
        expected[31] = 1
        XCTAssertEqual(AccountAddress.ONE.data, expected)
    }

    func testConstantThree() {
        var expected = Data(repeating: 0, count: 32)
        expected[31] = 3
        XCTAssertEqual(AccountAddress.THREE.data, expected)
    }

    func testConstantFour() {
        var expected = Data(repeating: 0, count: 32)
        expected[31] = 4
        XCTAssertEqual(AccountAddress.FOUR.data, expected)
    }

    // MARK: - isSpecial Detection

    func testIsSpecialForZeroThroughF() {
        XCTAssertTrue(AccountAddress.ZERO.isSpecial)
        XCTAssertTrue(AccountAddress.ONE.isSpecial)
        XCTAssertTrue(AccountAddress.THREE.isSpecial)
        XCTAssertTrue(AccountAddress.FOUR.isSpecial)
    }

    func testIsSpecialForValueAboveF() throws {
        // 0x10 last byte = 16, which is > 0x0F
        let addr = try AccountAddress.fromString("0x10")
        XCTAssertFalse(addr.isSpecial)
    }

    func testIsSpecialFalseWhenLeadingBytesNonZero() throws {
        // Non-zero byte at position 0, last byte < 0x10 -- still NOT special
        let hex = "0x01" + String(repeating: "0", count: 62)
        let addr = try AccountAddress.fromString(hex)
        XCTAssertFalse(addr.isSpecial)
    }

    func testIsSpecialForFF() throws {
        let addr = try AccountAddress.fromString("0xff")
        XCTAssertFalse(addr.isSpecial, "0xff is > 0x0f, so not special")
    }

    // MARK: - Equality

    func testEqualityOfSameAddress() throws {
        let a = try AccountAddress.fromString("0x1")
        let b = try AccountAddress.fromString("0x1")
        XCTAssertEqual(a, b)
    }

    func testInequalityOfDifferentAddresses() throws {
        let a = try AccountAddress.fromString("0x1")
        let b = try AccountAddress.fromString("0x2")
        XCTAssertNotEqual(a, b)
    }

    // MARK: - Hashable

    func testHashableWorks() throws {
        let a = try AccountAddress.fromString("0x1")
        let b = try AccountAddress.fromString("0x1")
        var set = Set<AccountAddress>()
        set.insert(a)
        set.insert(b)
        XCTAssertEqual(set.count, 1)
    }

    // MARK: - from() Factory

    func testFromStringInput() throws {
        let addr = try AccountAddress.from("0x1")
        XCTAssertEqual(addr, AccountAddress.ONE)
    }

    func testFromAddressInput() throws {
        let addr = try AccountAddress.from(AccountAddress.ONE)
        XCTAssertEqual(addr, AccountAddress.ONE)
    }

    // MARK: - fromData

    func testFromDataValid() throws {
        let data = Data(repeating: 0xAB, count: 32)
        let addr = try AccountAddress.fromData(data)
        XCTAssertEqual(addr.data, data)
    }

    func testFromDataInvalidLength() {
        XCTAssertThrowsError(try AccountAddress.fromData(Data(repeating: 0, count: 31)))
        XCTAssertThrowsError(try AccountAddress.fromData(Data(repeating: 0, count: 33)))
        XCTAssertThrowsError(try AccountAddress.fromData(Data()))
    }

    // MARK: - Codable

    func testCodableRoundTrip() throws {
        let original = AccountAddress.ONE
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AccountAddress.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testDecodableFromHexString() throws {
        let json = "\"0x1\""
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let addr = try decoder.decode(AccountAddress.self, from: data)
        XCTAssertEqual(addr, AccountAddress.ONE)
    }

    func testEncodableProducesLongForm() throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(AccountAddress.ONE)
        let jsonStr = String(data: data, encoding: .utf8)!
        // Should contain the full 64-digit hex
        XCTAssertTrue(jsonStr.contains(String(repeating: "0", count: 63) + "1"))
    }
}
