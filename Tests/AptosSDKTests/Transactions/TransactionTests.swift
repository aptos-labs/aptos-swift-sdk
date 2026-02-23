import Foundation
import Testing
@testable import AptosSDK

@Suite("Transaction Tests")
struct TransactionTests {
    @Test("Build simple transaction with builder")
    func buildSimpleTransaction() throws {
        let sender = try AccountAddress.fromHex("0x1")
        let payload = TransactionPayload.entryFunction(
            try EntryFunction.aptTransfer(to: AccountAddress.fromHex("0x2"), amount: 1000)
        )

        let raw = try TransactionBuilder()
            .sender(sender)
            .sequenceNumber(0)
            .payload(payload)
            .maxGasAmount(200_000)
            .gasUnitPrice(100)
            .expirationTimestampSecs(1_000_000)
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
            expirationTimestampSecs: 1_000_000,
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
            expirationTimestampSecs: 1_000_000,
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

    @Test("TransactionAPI has getTransactions method")
    func getTransactionsMethodExists() {
        // Compile-time check: verify getTransactions exists on TransactionAPI
        // by referencing its type signature through a closure
        let _: (TransactionAPI) -> (UInt64?, Int?) async throws -> [TransactionResponse] = { api in
            { start, limit in
                try await api.getTransactions(
                    start: start,
                    limit: limit
                )
            }
        }
    }

    @Test("TransactionAPI has estimateGasAmount method")
    func estimateGasAmountMethodExists() {
        // Compile-time check: verify estimateGasAmount exists on TransactionAPI
        let _: (TransactionAPI) -> (AnyRawTransaction, (any BCSSerializable)?) async throws -> UInt64 = { api in
            { txn, key in
                try await api.estimateGasAmount(
                    transaction: txn,
                    signerPublicKey: key
                )
            }
        }
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
            expirationTimestampSecs: 1_000_000,
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
            transaction: txn, senderAuthenticator: auth
        )

        // Should be serializable
        let bcs = try signed.toBytes()
        #expect(!bcs.isEmpty)
    }

    @Test("createSignedTransaction rejects missing fee payer authenticator")
    func createSignedTransactionMissingFeePayerAuthenticator() throws {
        let sender = try Ed25519Account.generate()
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
        let tx = SimpleTransaction(
            rawTransaction: raw,
            feePayerAddress: try AccountAddress.fromHex("0x4")
        )
        let senderAuth = try TransactionSigner.sign(transaction: .simple(tx), signer: sender)
        #expect(throws: AptosError.self) {
            _ = try TransactionSigner.createSignedTransaction(
                transaction: tx,
                senderAuthenticator: senderAuth
            )
        }
    }

    @Test("createSignedTransaction rejects unexpected fee payer authenticator")
    func createSignedTransactionUnexpectedFeePayerAuthenticator() throws {
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
        let tx = SimpleTransaction(rawTransaction: raw)
        let senderAuth = try TransactionSigner.sign(transaction: .simple(tx), signer: sender)
        let feePayerAuth = try TransactionSigner.signAsFeePayer(transaction: .simple(tx), feePayer: feePayer)

        #expect(throws: AptosError.self) {
            _ = try TransactionSigner.createSignedTransaction(
                transaction: tx,
                senderAuthenticator: senderAuth,
                feePayerAuthenticator: feePayerAuth
            )
        }
    }
}
