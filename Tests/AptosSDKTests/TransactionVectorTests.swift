import Foundation
import Testing
@testable import AptosSDK

@Suite("Transaction Test Vectors")
struct TransactionVectorTests {
    // MARK: - Chain IDs

    @Test("Chain ID constants")
    func chainIds() {
        #expect(ChainId.mainnet.value == 1)
        #expect(ChainId.testnet.value == 2)
        #expect(ChainId.devnet.value == 3)
        #expect(ChainId.local.value == 4)
    }

    // MARK: - BCS Encoding Vectors

    @Test("BCS bool true")
    func bcsBoolTrue() {
        var s = Serializer()
        s.serializeBool(true)
        #expect(dataToHex(s.toBytes()) == "01")
    }

    @Test("BCS bool false")
    func bcsBoolFalse() {
        var s = Serializer()
        s.serializeBool(false)
        #expect(dataToHex(s.toBytes()) == "00")
    }

    @Test("BCS u8 zero")
    func bcsU8Zero() {
        var s = Serializer()
        s.serializeU8(0)
        #expect(dataToHex(s.toBytes()) == "00")
    }

    @Test("BCS u8 max")
    func bcsU8Max() {
        var s = Serializer()
        s.serializeU8(255)
        #expect(dataToHex(s.toBytes()) == "ff")
    }

    @Test("BCS u16 256")
    func bcsU16() {
        var s = Serializer()
        s.serializeU16(256)
        #expect(dataToHex(s.toBytes()) == "0001")
    }

    @Test("BCS u32 0x12345678")
    func bcsU32() {
        var s = Serializer()
        s.serializeU32(305_419_896) // 0x12345678
        #expect(dataToHex(s.toBytes()) == "78563412")
    }

    @Test("BCS u64 million")
    func bcsU64Million() {
        var s = Serializer()
        s.serializeU64(1_000_000)
        #expect(dataToHex(s.toBytes()) == "40420f0000000000")
    }

    @Test("BCS empty string")
    func bcsEmptyString() throws {
        var s = Serializer()
        try s.serializeStr("")
        #expect(dataToHex(s.toBytes()) == "00")
    }

    @Test("BCS hello string")
    func bcsHelloString() throws {
        var s = Serializer()
        try s.serializeStr("hello")
        #expect(dataToHex(s.toBytes()) == "0568656c6c6f")
    }

    @Test("BCS bytes [1,2,3]")
    func bcsBytes123() throws {
        var s = Serializer()
        try s.serializeBytes([1, 2, 3])
        #expect(dataToHex(s.toBytes()) == "03010203")
    }

    // MARK: - ULEB128 in Transaction Context

    @Test("ULEB128 transaction-relevant values", arguments: [
        (UInt32(0), "00"), (UInt32(1), "01"), (UInt32(127), "7f"),
        (UInt32(128), "8001"), (UInt32(255), "ff01"),
        (UInt32(16383), "ff7f"), (UInt32(16384), "808001"),
    ])
    func txnUleb128(value: UInt32, hex: String) throws {
        var s = Serializer()
        try s.serializeU32AsUleb128(value)
        #expect(dataToHex(s.toBytes()) == hex)
    }

    // MARK: - Signing Message Domain Prefixes

    @Test("Single signer signing message domain prefix")
    func singleSignerPrefix() {
        let prefix = AptosHashing.signingPrefix("APTOS::RawTransaction")
        #expect(dataToHex(prefix) == "b5e97db07fa0bd0e5598aa3643a9bc6f6693bddc1a9fec9e674a461eaa00b193")
    }

    @Test("Multi agent signing message domain prefix")
    func multiAgentPrefix() {
        let prefix = AptosHashing.signingPrefix("APTOS::RawTransactionWithData")
        #expect(dataToHex(prefix) == "5efa3c4f02f83a0f4b2d69fc95c607cc02825cc4e7be536ef0992df050d9e67c")
    }

    @Test("Fee payer signing message uses same domain as multi agent")
    func feePayerPrefix() {
        let prefix = AptosHashing.signingPrefix("APTOS::RawTransactionWithData")
        #expect(dataToHex(prefix) == "5efa3c4f02f83a0f4b2d69fc95c607cc02825cc4e7be536ef0992df050d9e67c")
    }

    @Test("Transaction hash domain prefix")
    func txnHashPrefix() {
        let prefix = AptosHashing.signingPrefix("APTOS::Transaction")
        #expect(dataToHex(prefix) == "fa210a9417ef3e7fa45bfa1d17a8dbd4d883711910a550d265fee189e9266dd4")
    }

    // MARK: - Default Constants

    @Test("Default transaction expiry is 600 seconds (spec)")
    func defaultExpiry() {
        #expect(AptosConstants.defaultTxnExpirySecs == 600)
    }

    @Test("Default transaction timeout is 30 seconds (spec)")
    func defaultTimeout() {
        #expect(AptosConstants.defaultTxnTimeoutSecs == 30)
    }

    // MARK: - Address BCS in Transaction Context

    @Test("BCS address zero")
    func bcsAddrZero() throws {
        let addr = try AccountAddress.fromHex("0x0")
        let bcs = try bcsToBytes(addr)
        #expect(dataToHex(bcs) == "0000000000000000000000000000000000000000000000000000000000000000")
    }

    @Test("BCS address one")
    func bcsAddrOne() throws {
        let addr = try AccountAddress.fromHex("0x1")
        let bcs = try bcsToBytes(addr)
        #expect(dataToHex(bcs) == "0000000000000000000000000000000000000000000000000000000000000001")
    }

    @Test("BCS address max")
    func bcsAddrMax() throws {
        let addr = try AccountAddress.fromHex("0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff")
        let bcs = try bcsToBytes(addr)
        #expect(dataToHex(bcs) == "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff")
    }
}
