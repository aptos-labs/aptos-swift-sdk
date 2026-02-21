import Foundation
import Testing
@testable import AptosSDK

@Suite("Multi-Agent Tests")
struct MultiAgentTests {
    @Test("Build multi-agent transaction")
    func buildMultiAgent() throws {
        let sender = try AccountAddress.fromHex("0x1")
        let secondary1 = try AccountAddress.fromHex("0x2")
        let secondary2 = try AccountAddress.fromHex("0x3")

        let raw = RawTransaction(
            sender: sender,
            sequenceNumber: 0,
            payload: .entryFunction(EntryFunction(
                moduleId: MoveModuleId(address: .one, name: "aptos_account"),
                functionName: "transfer"
            )),
            maxGasAmount: 200_000,
            gasUnitPrice: 100,
            expirationTimestampSecs: 1_000_000,
            chainId: .testnet
        )

        let multiAgent = MultiAgentUtils.buildMultiAgentTransaction(
            rawTransaction: raw,
            secondarySignerAddresses: [secondary1, secondary2]
        )

        #expect(multiAgent.secondarySignerAddresses.count == 2)
        #expect(multiAgent.feePayerAddress == nil)
    }

    @Test("Multi-agent signing message differs from simple")
    func signingMessageDiffers() throws {
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

        let simple = SimpleTransaction(rawTransaction: raw)
        let multiAgent = MultiAgentTransaction(
            rawTransaction: raw,
            secondarySignerAddresses: [try AccountAddress.fromHex("0x2")]
        )

        let simpleMsg = try simple.signingMessage()
        let multiMsg = try multiAgent.signingMessage()

        // Different domain separators → different signing messages
        #expect(simpleMsg != multiMsg)
    }

    @Test("Sign multi-agent transaction with multiple signers")
    func signMultiAgent() throws {
        let sender = try Ed25519Account.generate()
        let secondary = try Ed25519Account.generate()

        let raw = RawTransaction(
            sender: sender.accountAddress,
            sequenceNumber: 0,
            payload: .entryFunction(EntryFunction(
                moduleId: MoveModuleId(address: .one, name: "aptos_account"),
                functionName: "transfer",
                typeArgs: [],
                args: [
                    try bcsToBytes(secondary.accountAddress),
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

        let signed = try MultiAgentUtils.signMultiAgentTransaction(
            transaction: MultiAgentUtils.buildMultiAgentTransaction(
                rawTransaction: raw,
                secondarySignerAddresses: [secondary.accountAddress]
            ),
            sender: sender,
            secondarySigners: [secondary]
        )

        // Should produce multiAgent authenticator
        if case let .multiAgent(_, addrs, signers) = signed.authenticator {
            #expect(addrs.count == 1)
            #expect(signers.count == 1)
        } else {
            Issue.record("Expected multiAgent authenticator")
        }

        // Should be serializable
        let bcs = try signed.toBytes()
        #expect(!bcs.isEmpty)
    }

    @Test("Multi-agent with fee payer")
    func multiAgentWithFeePayer() throws {
        let sender = try Ed25519Account.generate()
        let secondary = try Ed25519Account.generate()
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

        let signed = try MultiAgentUtils.signMultiAgentTransaction(
            transaction: MultiAgentUtils.buildMultiAgentTransaction(
                rawTransaction: raw,
                secondarySignerAddresses: [secondary.accountAddress],
                feePayerAddress: feePayer.accountAddress
            ),
            sender: sender,
            secondarySigners: [secondary],
            feePayer: feePayer
        )

        if case let .feePayer(_, addrs, signers, feeAddr, _) = signed.authenticator {
            #expect(addrs.count == 1)
            #expect(signers.count == 1)
            #expect(feeAddr == feePayer.accountAddress)
        } else {
            Issue.record("Expected feePayer authenticator")
        }
    }

    @Test("RawTransactionWithData BCS roundtrip - multi-agent")
    func rawTxnWithDataRoundtripMultiAgent() throws {
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

        let withData = RawTransactionWithData.multiAgent(
            rawTransaction: raw,
            secondarySignerAddresses: [try AccountAddress.fromHex("0x2"), try AccountAddress.fromHex("0x3")]
        )

        let bytes = try bcsToBytes(withData)
        let decoded = try bcsFromBytes(RawTransactionWithData.self, bytes)
        #expect(decoded == withData)
    }

    @Test("RawTransactionWithData BCS roundtrip - fee payer")
    func rawTxnWithDataRoundtripFeePayer() throws {
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

        let withData = RawTransactionWithData.feePayer(
            rawTransaction: raw,
            secondarySignerAddresses: [try AccountAddress.fromHex("0x2")],
            feePayerAddress: try AccountAddress.fromHex("0x4")
        )

        let bytes = try bcsToBytes(withData)
        let decoded = try bcsFromBytes(RawTransactionWithData.self, bytes)
        #expect(decoded == withData)
    }

    @Test("Multi-agent signing validates secondary signer count")
    func multiAgentSignerCountValidation() throws {
        let sender = try Ed25519Account.generate()
        let secondaryAddress = try AccountAddress.fromHex("0x2")
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

        let tx = MultiAgentUtils.buildMultiAgentTransaction(
            rawTransaction: raw,
            secondarySignerAddresses: [secondaryAddress]
        )

        #expect(throws: AptosError.self) {
            _ = try MultiAgentUtils.signMultiAgentTransaction(
                transaction: tx,
                sender: sender,
                secondarySigners: []
            )
        }
    }

    @Test("Multi-agent fee payer address requires fee payer signer")
    func multiAgentFeePayerRequiresSigner() throws {
        let sender = try Ed25519Account.generate()
        let secondary = try Ed25519Account.generate()
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

        let tx = MultiAgentUtils.buildMultiAgentTransaction(
            rawTransaction: raw,
            secondarySignerAddresses: [secondary.accountAddress],
            feePayerAddress: try AccountAddress.fromHex("0x4")
        )

        #expect(throws: AptosError.self) {
            _ = try MultiAgentUtils.signMultiAgentTransaction(
                transaction: tx,
                sender: sender,
                secondarySigners: [secondary]
            )
        }
    }
}
