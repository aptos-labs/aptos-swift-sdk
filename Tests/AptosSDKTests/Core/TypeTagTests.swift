import Foundation
import Testing
@testable import AptosSDK

@Suite("TypeTag Tests")
struct TypeTagTests {
    @Test("Parse primitive types")
    func parsePrimitives() throws {
        #expect(try TypeTag.fromString("bool") == .bool)
        #expect(try TypeTag.fromString("u8") == .u8)
        #expect(try TypeTag.fromString("u16") == .u16)
        #expect(try TypeTag.fromString("u32") == .u32)
        #expect(try TypeTag.fromString("u64") == .u64)
        #expect(try TypeTag.fromString("u128") == .u128)
        #expect(try TypeTag.fromString("u256") == .u256)
        #expect(try TypeTag.fromString("address") == .address)
        #expect(try TypeTag.fromString("signer") == .signer)
    }

    @Test("Parse vector type")
    func parseVector() throws {
        let tag = try TypeTag.fromString("vector<u8>")
        #expect(tag == .vector(.u8))
    }

    @Test("Parse nested vector")
    func parseNestedVector() throws {
        let tag = try TypeTag.fromString("vector<vector<u8>>")
        #expect(tag == .vector(.vector(.u8)))
    }

    @Test("Parse struct tag")
    func parseStructTag() throws {
        let tag = try TypeTag.fromString("0x1::aptos_coin::AptosCoin")
        if case let .structTag(st) = tag {
            #expect(st.address == AccountAddress.one)
            #expect(st.module == "aptos_coin")
            #expect(st.name == "AptosCoin")
            #expect(st.typeArgs.isEmpty)
        } else {
            Issue.record("Expected struct tag")
        }
    }

    @Test("Parse struct tag with type args")
    func parseStructTagWithTypeArgs() throws {
        let tag = try TypeTag.fromString("0x1::coin::CoinStore<0x1::aptos_coin::AptosCoin>")
        if case let .structTag(st) = tag {
            #expect(st.module == "coin")
            #expect(st.name == "CoinStore")
            #expect(st.typeArgs.count == 1)
            if case let .structTag(innerSt) = st.typeArgs[0] {
                #expect(innerSt.module == "aptos_coin")
                #expect(innerSt.name == "AptosCoin")
            } else {
                Issue.record("Expected inner struct tag")
            }
        } else {
            Issue.record("Expected struct tag")
        }
    }

    @Test("TypeTag description roundtrip")
    func descriptionRoundtrip() throws {
        let tags = ["bool", "u8", "u64", "address", "vector<u8>"]
        for str in tags {
            let tag = try TypeTag.fromString(str)
            #expect(tag.description == str)
        }
    }

    @Test("BCS roundtrip for primitives")
    func bcsRoundtripPrimitives() throws {
        for tag in [TypeTag.bool, .u8, .u16, .u32, .u64, .u128, .u256, .address, .signer] {
            let data = try bcsToBytes(tag)
            let decoded = try bcsFromBytes(TypeTag.self, data)
            #expect(decoded == tag)
        }
    }

    @Test("BCS roundtrip for vector")
    func bcsRoundtripVector() throws {
        let tag = TypeTag.vector(.u64)
        let data = try bcsToBytes(tag)
        let decoded = try bcsFromBytes(TypeTag.self, data)
        #expect(decoded == tag)
    }
}
