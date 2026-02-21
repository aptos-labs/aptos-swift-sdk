import Foundation
import Testing
@testable import AptosSDK

@Suite("TypeTag Test Vectors")
struct TypeTagVectorTests {
    // MARK: - Primitive Types

    @Test("Parse primitive type 'bool'")
    func parseBool() throws {
        let tag = try TypeTag.fromString("bool")
        #expect(tag == .bool)
    }

    @Test("Parse primitive type 'u8'")
    func parseU8() throws {
        let tag = try TypeTag.fromString("u8")
        #expect(tag == .u8)
    }

    @Test("Parse primitive type 'u16'")
    func parseU16() throws {
        let tag = try TypeTag.fromString("u16")
        #expect(tag == .u16)
    }

    @Test("Parse primitive type 'u32'")
    func parseU32() throws {
        let tag = try TypeTag.fromString("u32")
        #expect(tag == .u32)
    }

    @Test("Parse primitive type 'u64'")
    func parseU64() throws {
        let tag = try TypeTag.fromString("u64")
        #expect(tag == .u64)
    }

    @Test("Parse primitive type 'u128'")
    func parseU128() throws {
        let tag = try TypeTag.fromString("u128")
        #expect(tag == .u128)
    }

    @Test("Parse primitive type 'u256'")
    func parseU256() throws {
        let tag = try TypeTag.fromString("u256")
        #expect(tag == .u256)
    }

    @Test("Parse primitive type 'address'")
    func parseAddress() throws {
        let tag = try TypeTag.fromString("address")
        #expect(tag == .address)
    }

    @Test("Parse primitive type 'signer'")
    func parseSigner() throws {
        let tag = try TypeTag.fromString("signer")
        #expect(tag == .signer)
    }

    // MARK: - Vector Types

    @Test("Parse vector<u8>")
    func parseVectorU8() throws {
        let tag = try TypeTag.fromString("vector<u8>")
        if case let .vector(inner) = tag {
            #expect(inner == .u8)
        } else {
            Issue.record("Expected vector type")
        }
    }

    @Test("Parse vector<address>")
    func parseVectorAddress() throws {
        let tag = try TypeTag.fromString("vector<address>")
        if case let .vector(inner) = tag {
            #expect(inner == .address)
        } else {
            Issue.record("Expected vector type")
        }
    }

    @Test("Parse vector<u64>")
    func parseVectorU64() throws {
        let tag = try TypeTag.fromString("vector<u64>")
        if case let .vector(inner) = tag {
            #expect(inner == .u64)
        } else {
            Issue.record("Expected vector type")
        }
    }

    @Test("Parse nested vector<vector<u8>>")
    func parseNestedVector() throws {
        let tag = try TypeTag.fromString("vector<vector<u8>>")
        if case let .vector(outer) = tag, case let .vector(inner) = outer {
            #expect(inner == .u8)
        } else {
            Issue.record("Expected nested vector type")
        }
    }

    @Test("Parse vector of struct")
    func parseVectorOfStruct() throws {
        let tag = try TypeTag.fromString("vector<0x1::aptos_coin::AptosCoin>")
        if case let .vector(inner) = tag, case .structTag = inner {
            // Valid struct inside vector
        } else {
            Issue.record("Expected vector of struct type")
        }
    }

    // MARK: - Struct Types

    @Test("Parse AptosCoin struct")
    func parseAptosCoin() throws {
        let tag = try TypeTag.fromString("0x1::aptos_coin::AptosCoin")
        if case let .structTag(st) = tag {
            #expect(st.address.toShortString() == "0x1")
            #expect(st.module == "aptos_coin")
            #expect(st.name == "AptosCoin")
            #expect(st.typeArgs.isEmpty)
        } else {
            Issue.record("Expected struct type")
        }
    }

    @Test("Parse CoinStore with type arg")
    func parseCoinStore() throws {
        let tag = try TypeTag.fromString("0x1::coin::CoinStore<0x1::aptos_coin::AptosCoin>")
        if case let .structTag(st) = tag {
            #expect(st.address.toShortString() == "0x1")
            #expect(st.module == "coin")
            #expect(st.name == "CoinStore")
            #expect(st.typeArgs.count == 1)
        } else {
            Issue.record("Expected struct type")
        }
    }

    @Test("Parse struct with multiple type args")
    func parseMultipleTypeArgs() throws {
        let tag = try TypeTag.fromString("0x1::pool::LiquidityPool<0x1::coin_a::CoinA, 0x1::coin_b::CoinB>")
        if case let .structTag(st) = tag {
            #expect(st.module == "pool")
            #expect(st.name == "LiquidityPool")
            #expect(st.typeArgs.count == 2)
        } else {
            Issue.record("Expected struct type")
        }
    }

    @Test("Parse nested generics")
    func parseNestedGenerics() throws {
        let tag = try TypeTag.fromString("0x1::option::Option<0x1::coin::Coin<0x1::aptos_coin::AptosCoin>>")
        if case let .structTag(st) = tag {
            #expect(st.module == "option")
            #expect(st.name == "Option")
            #expect(st.typeArgs.count == 1)
            // Inner type arg should be a struct with its own type arg
            if case let .structTag(inner) = st.typeArgs[0] {
                #expect(inner.module == "coin")
                #expect(inner.name == "Coin")
                #expect(inner.typeArgs.count == 1)
            } else {
                Issue.record("Expected nested struct type arg")
            }
        } else {
            Issue.record("Expected struct type")
        }
    }

    @Test("Parse long address struct")
    func parseLongAddressStruct() throws {
        let tag = try TypeTag
            .fromString("0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890::my_module::MyStruct")
        if case let .structTag(st) = tag {
            #expect(st.module == "my_module")
            #expect(st.name == "MyStruct")
            #expect(st.typeArgs.isEmpty)
        } else {
            Issue.record("Expected struct type")
        }
    }

    // MARK: - Invalid Type Strings

    @Test("Empty string is invalid")
    func emptyInvalid() {
        #expect(throws: (any Error).self) {
            try TypeTag.fromString("")
        }
    }

    @Test("Unknown primitive 'int' is invalid")
    func unknownPrimitive() {
        #expect(throws: (any Error).self) {
            try TypeTag.fromString("int")
        }
    }

    @Test("Unclosed vector is invalid")
    func unclosedVector() {
        #expect(throws: (any Error).self) {
            try TypeTag.fromString("vector<u8")
        }
    }

    @Test("Empty vector is invalid")
    func emptyVector() {
        #expect(throws: (any Error).self) {
            try TypeTag.fromString("vector<>")
        }
    }

    @Test("Invalid address format is invalid")
    func invalidAddress() {
        #expect(throws: (any Error).self) {
            try TypeTag.fromString("invalid::module::Struct")
        }
    }

    @Test("Unclosed generic is invalid")
    func unclosedGeneric() {
        #expect(throws: (any Error).self) {
            try TypeTag.fromString("0x1::coin::Coin<0x1::aptos_coin::AptosCoin")
        }
    }

    @Test("Double colon only is invalid")
    func doubleColonOnly() {
        #expect(throws: (any Error).self) {
            try TypeTag.fromString("::")
        }
    }

    // MARK: - BCS Serialization

    @Test("BCS u64 type tag")
    func bcsU64() throws {
        let tag = TypeTag.u64
        let bcs = try bcsToBytes(tag)
        #expect(dataToHex(bcs) == "02")
    }

    @Test("BCS vector<u8> type tag")
    func bcsVectorU8() throws {
        let tag = try TypeTag.fromString("vector<u8>")
        let bcs = try bcsToBytes(tag)
        #expect(dataToHex(bcs) == "0601")
    }
}
