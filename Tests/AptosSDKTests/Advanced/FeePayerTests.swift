import Foundation
import Testing
@testable import AptosSDK

@Suite("Fee Payer Tests")
struct FeePayerTests {
    @Test("Build fee payer transaction")
    func buildFeePayerTransaction() throws {
        let raw = RawTransaction(
            sender: .one,
            sequenceNumber: 0,
            payload: .entryFunction(EntryFunction(
                moduleId: MoveModuleId(address: .one, name: "test"),
                functionName: "test"
            )),
            maxGasAmount: 200_000,
            gasUnitPrice: 100,
            expirationTimestampSecs: 1_000_000,
            chainId: .testnet
        )

        let feePayer = try AccountAddress.fromHex("0x5")
        let txn = FeePayerUtils.buildFeePayerTransaction(
            rawTransaction: raw,
            feePayerAddress: feePayer
        )

        #expect(txn.feePayerAddress == feePayer)
        #expect(txn.rawTransaction == raw)
    }

    @Test("Fee payer signing message includes fee payer address")
    func feePayerSigningMessage() throws {
        let raw = RawTransaction(
            sender: .one,
            sequenceNumber: 0,
            payload: .entryFunction(EntryFunction(
                moduleId: MoveModuleId(address: .one, name: "test"),
                functionName: "test"
            )),
            maxGasAmount: 200_000,
            gasUnitPrice: 100,
            expirationTimestampSecs: 1_000_000,
            chainId: .testnet
        )

        let withoutFeePayer = SimpleTransaction(rawTransaction: raw)
        let withFeePayer = SimpleTransaction(
            rawTransaction: raw,
            feePayerAddress: try AccountAddress.fromHex("0x5")
        )

        let msg1 = try withoutFeePayer.signingMessage()
        let msg2 = try withFeePayer.signingMessage()

        // Different: one uses RawTransaction prefix, other uses RawTransactionWithData prefix
        #expect(msg1 != msg2)
        #expect(msg2.count > msg1.count) // Fee payer message is larger
    }

    @Test("Sign fee payer transaction")
    func signFeePayerTransaction() throws {
        let sender = try Ed25519Account.generate()
        let feePayer = try Ed25519Account.generate()

        let raw = RawTransaction(
            sender: sender.accountAddress,
            sequenceNumber: 0,
            payload: .entryFunction(EntryFunction(
                moduleId: MoveModuleId(address: .one, name: "aptos_account"),
                functionName: "transfer",
                typeArgs: [],
                args: [
                    try bcsToBytes(AccountAddress.fromHex("0x2")),
                    {
                        var s = Serializer()
                        s.serializeU64(1000)
                        return s.toBytes()
                    }(),
                ]
            )),
            maxGasAmount: 200_000,
            gasUnitPrice: 100,
            expirationTimestampSecs: 1_000_000,
            chainId: .testnet
        )

        let txn = FeePayerUtils.buildFeePayerTransaction(
            rawTransaction: raw,
            feePayerAddress: feePayer.accountAddress
        )

        let signed = try FeePayerUtils.signFeePayerTransaction(
            transaction: txn,
            sender: sender,
            feePayer: feePayer
        )

        // Should produce fee payer authenticator
        if case let .feePayer(_, addrs, signers, feeAddr, _) = signed.authenticator {
            #expect(addrs.isEmpty) // No secondary signers
            #expect(signers.isEmpty)
            #expect(feeAddr == feePayer.accountAddress)
        } else {
            Issue.record("Expected feePayer authenticator")
        }

        // Should be serializable
        let bcs = try signed.toBytes()
        #expect(!bcs.isEmpty)
    }

    @Test("Transaction without fee payer address throws")
    func noFeePayerThrows() throws {
        let sender = try Ed25519Account.generate()
        let feePayer = try Ed25519Account.generate()

        let raw = RawTransaction(
            sender: sender.accountAddress,
            sequenceNumber: 0,
            payload: .entryFunction(EntryFunction(
                moduleId: MoveModuleId(address: .one, name: "test"),
                functionName: "test"
            )),
            maxGasAmount: 200_000,
            gasUnitPrice: 100,
            expirationTimestampSecs: 1_000_000,
            chainId: .testnet
        )

        // SimpleTransaction without feePayerAddress
        let txn = SimpleTransaction(rawTransaction: raw)

        #expect(throws: AptosError.self) {
            try FeePayerUtils.signFeePayerTransaction(
                transaction: txn,
                sender: sender,
                feePayer: feePayer
            )
        }
    }

    @Test("Mismatched fee payer account/address throws")
    func mismatchedFeePayerAccountAddress() throws {
        let sender = try Ed25519Account.generate()
        let expectedFeePayer = try Ed25519Account.generate()
        let wrongFeePayer = try Ed25519Account.generate()

        let raw = RawTransaction(
            sender: sender.accountAddress,
            sequenceNumber: 0,
            payload: .entryFunction(EntryFunction(
                moduleId: MoveModuleId(address: .one, name: "test"),
                functionName: "test"
            )),
            maxGasAmount: 200_000,
            gasUnitPrice: 100,
            expirationTimestampSecs: 1_000_000,
            chainId: .testnet
        )

        let txn = FeePayerUtils.buildFeePayerTransaction(
            rawTransaction: raw,
            feePayerAddress: expectedFeePayer.accountAddress
        )

        #expect(throws: AptosError.self) {
            try FeePayerUtils.signFeePayerTransaction(
                transaction: txn,
                sender: sender,
                feePayer: wrongFeePayer
            )
        }
    }
}
