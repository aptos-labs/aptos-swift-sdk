import Foundation
import Testing
@testable import AptosSDK

@Suite("Address Test Vectors")
struct AddressVectorTests {
    // MARK: - Parsing Vectors

    @Test("Parse framework address short")
    func parseFrameworkShort() throws {
        let addr = try AccountAddress.fromHex("0x1")
        #expect(addr.toHex() == "0x0000000000000000000000000000000000000000000000000000000000000001")
        #expect(addr.toShortString() == "0x1")
    }

    @Test("Parse framework address without prefix")
    func parseNoPrefix() throws {
        let addr = try AccountAddress.fromHex("1")
        #expect(addr.toHex() == "0x0000000000000000000000000000000000000000000000000000000000000001")
        #expect(addr.toShortString() == "0x1")
    }

    @Test("Parse full 64-char address")
    func parseFull() throws {
        let addr = try AccountAddress.fromHex("0x0000000000000000000000000000000000000000000000000000000000000001")
        #expect(addr.toHex() == "0x0000000000000000000000000000000000000000000000000000000000000001")
        #expect(addr.toShortString() == "0x1")
    }

    @Test("Parse two-digit hex address")
    func parseTwoDigit() throws {
        let addr = try AccountAddress.fromHex("0x10")
        #expect(addr.toHex() == "0x0000000000000000000000000000000000000000000000000000000000000010")
        #expect(addr.toShortString() == "0x10")
        #expect(addr.data.last == 16)
    }

    @Test("Parse max single byte address")
    func parseMaxSingleByte() throws {
        let addr = try AccountAddress.fromHex("0xff")
        #expect(addr.toHex() == "0x00000000000000000000000000000000000000000000000000000000000000ff")
        #expect(addr.toShortString() == "0xff")
        #expect(addr.data.last == 255)
    }

    @Test("Parse two-byte address")
    func parseTwoByte() throws {
        let addr = try AccountAddress.fromHex("0x100")
        #expect(addr.toHex() == "0x0000000000000000000000000000000000000000000000000000000000000100")
        #expect(addr.toShortString() == "0x100")
    }

    @Test("Parse uppercase hex")
    func parseUppercase() throws {
        let addr = try AccountAddress.fromHex("0xABCDEF")
        #expect(addr.toHex() == "0x0000000000000000000000000000000000000000000000000000000000abcdef")
        #expect(addr.toShortString() == "0xabcdef")
    }

    @Test("Parse mixed case hex")
    func parseMixedCase() throws {
        let addr = try AccountAddress.fromHex("0xAbCdEf123456")
        #expect(addr.toHex() == "0x0000000000000000000000000000000000000000000000000000abcdef123456")
        #expect(addr.toShortString() == "0xabcdef123456")
    }

    @Test("Parse leading non-zero byte address")
    func parseLeadingNonZero() throws {
        let addr = try AccountAddress.fromHex("0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef")
        #expect(addr.toHex() == "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef")
        #expect(addr.toShortString() == "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef")
    }

    @Test("Parse realistic account address")
    func parseRealistic() throws {
        let addr = try AccountAddress.fromHex("0x9c3a0eeb9f91075eefa4d1f58c02e59e9d34e41320a3ccb357e6a5c7bfa540fa")
        #expect(addr.toHex() == "0x9c3a0eeb9f91075eefa4d1f58c02e59e9d34e41320a3ccb357e6a5c7bfa540fa")
        #expect(addr.toShortString() == "0x9c3a0eeb9f91075eefa4d1f58c02e59e9d34e41320a3ccb357e6a5c7bfa540fa")
    }

    // MARK: - Constants

    @Test("ZERO constant")
    func zeroConstant() throws {
        let addr = try AccountAddress.fromHex("0x0")
        #expect(addr.toHex() == "0x0000000000000000000000000000000000000000000000000000000000000000")
        #expect(addr.toShortString() == "0x0")
        #expect(addr.data == Data(repeating: 0, count: 32))
    }

    @Test("ONE constant")
    func oneConstant() throws {
        let addr = try AccountAddress.fromHex("0x1")
        var expected = Data(repeating: 0, count: 32)
        expected[31] = 1
        #expect(addr.data == expected)
    }

    @Test("THREE constant")
    func threeConstant() throws {
        let addr = try AccountAddress.fromHex("0x3")
        var expected = Data(repeating: 0, count: 32)
        expected[31] = 3
        #expect(addr.data == expected)
    }

    @Test("FOUR constant")
    func fourConstant() throws {
        let addr = try AccountAddress.fromHex("0x4")
        var expected = Data(repeating: 0, count: 32)
        expected[31] = 4
        #expect(addr.data == expected)
    }

    // MARK: - Invalid Inputs

    @Test("Empty string throws")
    func emptyString() {
        #expect(throws: (any Error).self) {
            try AccountAddress.fromHex("")
        }
    }

    @Test("Only prefix throws")
    func onlyPrefix() {
        #expect(throws: (any Error).self) {
            try AccountAddress.fromHex("0x")
        }
    }

    @Test("Invalid hex characters throw")
    func invalidHex() {
        #expect(throws: (any Error).self) {
            try AccountAddress.fromHex("0xGHIJKL")
        }
    }

    @Test("Too long address throws")
    func tooLong() {
        #expect(throws: (any Error).self) {
            try AccountAddress.fromHex("0x00000000000000000000000000000000000000000000000000000000000000001")
        }
    }

    @Test("Spaces in address throws")
    func spacesInAddress() {
        #expect(throws: (any Error).self) {
            try AccountAddress.fromHex("0x1 2 3")
        }
    }

    @Test("Special characters throw")
    func specialChars() {
        #expect(throws: (any Error).self) {
            try AccountAddress.fromHex("0x123!@#")
        }
    }

    // MARK: - BCS Serialization

    @Test("BCS serialization of address 0x1")
    func bcsAddressOne() throws {
        let addr = try AccountAddress.fromHex("0x1")
        let bcs = try bcsToBytes(addr)
        #expect(bcs.count == 32)
        #expect(dataToHex(bcs) == "0000000000000000000000000000000000000000000000000000000000000001")
    }

    @Test("BCS serialization of max address")
    func bcsAddressMax() throws {
        let addr = try AccountAddress.fromHex("0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff")
        let bcs = try bcsToBytes(addr)
        #expect(bcs.count == 32)
        #expect(dataToHex(bcs) == "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff")
    }
}
