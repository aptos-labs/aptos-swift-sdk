import BigInt
import Foundation
import XCTest

@testable import AptosSDK

final class PropertyTypeTests: XCTestCase {

    // MARK: - PropertyType moveTypeString Mapping

    func testBooleanMoveTypeString() {
        XCTAssertEqual(PropertyType.boolean.moveTypeString, "bool")
    }

    func testU8MoveTypeString() {
        XCTAssertEqual(PropertyType.u8.moveTypeString, "u8")
    }

    func testU16MoveTypeString() {
        XCTAssertEqual(PropertyType.u16.moveTypeString, "u16")
    }

    func testU32MoveTypeString() {
        XCTAssertEqual(PropertyType.u32.moveTypeString, "u32")
    }

    func testU64MoveTypeString() {
        XCTAssertEqual(PropertyType.u64.moveTypeString, "u64")
    }

    func testU128MoveTypeString() {
        XCTAssertEqual(PropertyType.u128.moveTypeString, "u128")
    }

    func testU256MoveTypeString() {
        XCTAssertEqual(PropertyType.u256.moveTypeString, "u256")
    }

    func testAddressMoveTypeString() {
        XCTAssertEqual(PropertyType.address.moveTypeString, "address")
    }

    func testStringMoveTypeString() {
        XCTAssertEqual(PropertyType.string.moveTypeString, "0x1::string::String")
    }

    func testArrayMoveTypeString() {
        XCTAssertEqual(PropertyType.array.moveTypeString, "vector<u8>")
    }

    // MARK: - PropertyType Raw Values

    func testPropertyTypeRawValues() {
        XCTAssertEqual(PropertyType.boolean.rawValue, "BOOLEAN")
        XCTAssertEqual(PropertyType.u8.rawValue, "U8")
        XCTAssertEqual(PropertyType.u16.rawValue, "U16")
        XCTAssertEqual(PropertyType.u32.rawValue, "U32")
        XCTAssertEqual(PropertyType.u64.rawValue, "U64")
        XCTAssertEqual(PropertyType.u128.rawValue, "U128")
        XCTAssertEqual(PropertyType.u256.rawValue, "U256")
        XCTAssertEqual(PropertyType.address.rawValue, "ADDRESS")
        XCTAssertEqual(PropertyType.string.rawValue, "STRING")
        XCTAssertEqual(PropertyType.array.rawValue, "ARRAY")
    }

    // MARK: - PropertyType CaseIterable

    func testAllCases() {
        let allCases = PropertyType.allCases
        XCTAssertEqual(allCases.count, 10)
    }

    // MARK: - PropertyValue propertyType

    func testPropertyValueBooleanType() {
        let value = PropertyValue.boolean(true)
        XCTAssertEqual(value.propertyType, .boolean)
    }

    func testPropertyValueU8Type() {
        let value = PropertyValue.u8(42)
        XCTAssertEqual(value.propertyType, .u8)
    }

    func testPropertyValueU16Type() {
        let value = PropertyValue.u16(1000)
        XCTAssertEqual(value.propertyType, .u16)
    }

    func testPropertyValueU32Type() {
        let value = PropertyValue.u32(100_000)
        XCTAssertEqual(value.propertyType, .u32)
    }

    func testPropertyValueU64Type() {
        let value = PropertyValue.u64(1_000_000)
        XCTAssertEqual(value.propertyType, .u64)
    }

    func testPropertyValueU128Type() {
        let value = PropertyValue.u128(BigUInt(999))
        XCTAssertEqual(value.propertyType, .u128)
    }

    func testPropertyValueU256Type() {
        let value = PropertyValue.u256(BigUInt(999))
        XCTAssertEqual(value.propertyType, .u256)
    }

    func testPropertyValueAddressType() {
        let value = PropertyValue.address(AccountAddress.ONE)
        XCTAssertEqual(value.propertyType, .address)
    }

    func testPropertyValueStringType() {
        let value = PropertyValue.string("hello")
        XCTAssertEqual(value.propertyType, .string)
    }

    func testPropertyValueArrayType() {
        let value = PropertyValue.array(Data([0x01, 0x02]))
        XCTAssertEqual(value.propertyType, .array)
    }

    // MARK: - PropertyValue toRawBytes Serialization

    func testBooleanTrueToRawBytes() {
        let bytes = PropertyValue.boolean(true).toRawBytes()
        XCTAssertEqual(bytes, Data([0x01]))
    }

    func testBooleanFalseToRawBytes() {
        let bytes = PropertyValue.boolean(false).toRawBytes()
        XCTAssertEqual(bytes, Data([0x00]))
    }

    func testU8ToRawBytes() {
        let bytes = PropertyValue.u8(255).toRawBytes()
        XCTAssertEqual(bytes, Data([0xFF]))
    }

    func testU16ToRawBytes() {
        let bytes = PropertyValue.u16(0x0102).toRawBytes()
        // Little-endian
        XCTAssertEqual(bytes, Data([0x02, 0x01]))
    }

    func testU32ToRawBytes() {
        let bytes = PropertyValue.u32(1).toRawBytes()
        XCTAssertEqual(bytes, Data([0x01, 0x00, 0x00, 0x00]))
    }

    func testU64ToRawBytes() {
        let bytes = PropertyValue.u64(1).toRawBytes()
        XCTAssertEqual(bytes, Data([0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]))
    }

    func testU128ToRawBytes() {
        let bytes = PropertyValue.u128(BigUInt(1)).toRawBytes()
        XCTAssertEqual(bytes.count, 16)
        var expected = Data(repeating: 0, count: 16)
        expected[0] = 0x01
        XCTAssertEqual(bytes, expected)
    }

    func testU256ToRawBytes() {
        let bytes = PropertyValue.u256(BigUInt(1)).toRawBytes()
        XCTAssertEqual(bytes.count, 32)
        var expected = Data(repeating: 0, count: 32)
        expected[0] = 0x01
        XCTAssertEqual(bytes, expected)
    }

    func testAddressToRawBytes() {
        let bytes = PropertyValue.address(AccountAddress.ONE).toRawBytes()
        // Fixed 32 bytes, no length prefix
        XCTAssertEqual(bytes.count, 32)
        XCTAssertEqual(bytes, AccountAddress.ONE.data)
    }

    func testStringToRawBytes() {
        let bytes = PropertyValue.string("hi").toRawBytes()
        // ULEB128(2) + "hi"
        XCTAssertEqual(bytes, Data([0x02, 0x68, 0x69]))
    }

    func testStringEmptyToRawBytes() {
        let bytes = PropertyValue.string("").toRawBytes()
        XCTAssertEqual(bytes, Data([0x00]))
    }

    func testArrayToRawBytes() {
        let payload = Data([0xCA, 0xFE])
        let bytes = PropertyValue.array(payload).toRawBytes()
        // serializeBytes: ULEB128(2) + 0xCA 0xFE
        XCTAssertEqual(bytes, Data([0x02, 0xCA, 0xFE]))
    }

    func testArrayEmptyToRawBytes() {
        let bytes = PropertyValue.array(Data()).toRawBytes()
        XCTAssertEqual(bytes, Data([0x00]))
    }

    // MARK: - PropertyUtils

    func testPreparePropertiesValid() throws {
        let keys = ["name", "age"]
        let types: [PropertyType] = [.string, .u8]
        let values: [PropertyValue] = [.string("Alice"), .u8(30)]

        let result = try PropertyUtils.prepareProperties(keys: keys, types: types, values: values)
        XCTAssertEqual(result.keys, ["name", "age"])
        XCTAssertEqual(result.types, ["0x1::string::String", "u8"])
        XCTAssertEqual(result.values.count, 2)
        // First value: BCS-encoded "Alice"
        let expectedAlice = PropertyValue.string("Alice").toRawBytes()
        XCTAssertEqual(result.values[0], expectedAlice)
        // Second value: BCS-encoded 30
        XCTAssertEqual(result.values[1], Data([30]))
    }

    func testPreparePropertiesMismatchedLengths() {
        let keys = ["name"]
        let types: [PropertyType] = [.string, .u8]
        let values: [PropertyValue] = [.string("Alice")]

        XCTAssertThrowsError(try PropertyUtils.prepareProperties(keys: keys, types: types, values: values)) { error in
            guard case AptosError.invalidArgument(let msg) = error else {
                XCTFail("Expected invalidArgument, got: \(error)")
                return
            }
            XCTAssertTrue(msg.contains("matching lengths"))
        }
    }

    func testPreparePropertiesEmpty() throws {
        let result = try PropertyUtils.prepareProperties(keys: [], types: [], values: [])
        XCTAssertTrue(result.keys.isEmpty)
        XCTAssertTrue(result.types.isEmpty)
        XCTAssertTrue(result.values.isEmpty)
    }
}
