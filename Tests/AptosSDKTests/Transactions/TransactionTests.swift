import Testing
import Foundation
@testable import AptosSDK

@Suite("Transaction Tests")
struct TransactionTests {
    @Test("Build simple transaction with builder")
    func buildSimpleTransaction() throws {
        let sender = try AccountAddress.fromHex("0x1")
        let payload = TransactionPayload.entryFunction(
            EntryFunction.aptTransfer(to: try AccountAddress.fromHex("0x2"), amount: 1000)
        )

        let raw = try TransactionBuilder()
            .sender(sender)
            .sequenceNumber(0)
            .payload(payload)
            .maxGasAmount(200_000)
            .gasUnitPrice(100)
            .expirationTimestampSecs(1000000)
            .chainId(.testnet)
            .build()

        #expect(raw.sender == sender)
        #expect(raw.sequenceNumber == 0)
        #expect(raw.maxGasAmount == 200_000)
        #expect(raw.gasUnitPrice == 100)
        #expect(raw.chainId == .testnet)
    }

    @Test("Builder missing sender throws")
    func builderMissingSender() throws {
        #expect(throws: AptosError.self) {
            try TransactionBuilder()
                .sequenceNumber(0)
                .payload(.entryFunction(EntryFunction(
                    moduleId: MoveModuleId(address: .one, name: "test"),
                    functionName: "test"
                )))
                .chainId(.testnet)
                .build()
        }
    }

    @Test("RawTransaction BCS roundtrip")
    func rawTransactionBCSRoundtrip() throws {
        let raw = RawTransaction(
            sender: try AccountAddress.fromHex("0x1"),
            sequenceNumber: 42,
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
            expirationTimestampSecs: 1000000,
            chainId: .testnet
        )

        let data = try bcsToBytes(raw)
        let decoded = try bcsFromBytes(RawTransaction.self, data)
        #expect(decoded == raw)
    }

    @Test("Signing message computation")
    func signingMessage() throws {
        let raw = RawTransaction(
            sender: .one,
            sequenceNumber: 0,
            payload: .entryFunction(EntryFunction(
                moduleId: MoveModuleId(address: .one, name: "test"),
                functionName: "test"
            )),
            maxGasAmount: 200_000,
            gasUnitPrice: 100,
            expirationTimestampSecs: 1000000,
            chainId: .testnet
        )

        let message = try raw.signingMessage()
        // Should start with SHA3-256("APTOS::RawTransaction") prefix (32 bytes)
        // followed by BCS-serialized raw transaction
        #expect(message.count > 32)
    }

    @Test("ChainId BCS roundtrip")
    func chainIdBCSRoundtrip() throws {
        let chainId = ChainId.testnet
        let data = try bcsToBytes(chainId)
        #expect(data == Data([2])) // Testnet = 2
        let decoded = try bcsFromBytes(ChainId.self, data)
        #expect(decoded == chainId)
    }

    @Test("SimpleTransaction signing")
    func simpleTransactionSigning() throws {
        let account = try Ed25519Account.generate()
        let raw = RawTransaction(
            sender: account.accountAddress,
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
            expirationTimestampSecs: 1000000,
            chainId: .testnet
        )

        let txn = SimpleTransaction(rawTransaction: raw)
        let auth = try TransactionSigner.sign(transaction: .simple(txn), signer: account)

        // Should produce Ed25519 authenticator
        if case .ed25519 = auth {
            // Expected for Ed25519Account
        } else {
            Issue.record("Expected Ed25519 authenticator")
        }

        // Create signed transaction
        let signed = try TransactionSigner.createSignedTransaction(
            transaction: txn, senderAuthenticator: auth)

        // Should be serializable
        let bcs = try signed.toBytes()
        #expect(bcs.count > 0)
    }
}
