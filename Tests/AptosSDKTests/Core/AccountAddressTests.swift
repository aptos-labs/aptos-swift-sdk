import Testing
import Foundation
@testable import AptosSDK

@Suite("AccountAddress Tests")
struct AccountAddressTests {
    @Test("Create from hex")
    func fromHex() throws {
        let addr = try AccountAddress.fromHex("0x1")
        #expect(addr.toShortString() == "0x1")
        #expect(addr.data[31] == 1)
        #expect(addr.data[0] == 0)
    }

    @Test("Create from full hex")
    func fromFullHex() throws {
        let fullHex = "0x0000000000000000000000000000000000000000000000000000000000000001"
        let addr = try AccountAddress.fromHex(fullHex)
        #expect(addr.toHex() == fullHex)
        #expect(addr.toShortString() == "0x1")
    }

    @Test("Special addresses use short form")
    func specialAddresses() throws {
        let zero = AccountAddress.zero
        #expect(zero.toShortString() == "0x0")
        #expect(zero.isSpecial)
        #expect(zero.description == "0x0")

        let one = AccountAddress.one
        #expect(one.toShortString() == "0x1")
        #expect(one.isSpecial)

        let four = AccountAddress.four
        #expect(four.toShortString() == "0x4")
        #expect(four.isSpecial)
    }

    @Test("Non-special address uses full form")
    func nonSpecialAddress() throws {
        let addr = try AccountAddress.fromHex("0x100")
        #expect(!addr.isSpecial)
        #expect(addr.description == addr.toHex())
    }

    @Test("Equality")
    func equality() throws {
        let a = try AccountAddress.fromHex("0x1")
        let b = try AccountAddress.fromHex("0x0000000000000000000000000000000000000000000000000000000000000001")
        #expect(a == b)
    }

    @Test("Comparable")
    func comparable() throws {
        let a = try AccountAddress.fromHex("0x1")
        let b = try AccountAddress.fromHex("0x2")
        #expect(a < b)
    }

    @Test("BCS roundtrip")
    func bcsRoundtrip() throws {
        let original = try AccountAddress.fromHex("0xCAFE")
        let data = try bcsToBytes(original)
        #expect(data.count == 32) // Fixed 32 bytes
        let decoded = try bcsFromBytes(AccountAddress.self, data)
        #expect(decoded == original)
    }

    @Test("Codable roundtrip")
    func codableRoundtrip() throws {
        let original = try AccountAddress.fromHex("0x1")
        let json = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AccountAddress.self, from: json)
        #expect(decoded == original)
    }

    @Test("Invalid hex throws")
    func invalidHex() throws {
        #expect(throws: AptosError.self) {
            try AccountAddress.fromHex("")
        }
    }

    @Test("Too long hex throws")
    func tooLongHex() throws {
        let longHex = "0x" + String(repeating: "F", count: 66)
        #expect(throws: AptosError.self) {
            try AccountAddress.fromHex(longHex)
        }
    }
}
