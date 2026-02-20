import Foundation
import XCTest

@testable import AptosSDK

final class AuthenticatorTests: XCTestCase {

    // MARK: - Helpers

    /// Generate a fresh Ed25519 keypair, sign a message, and return (publicKey, signature).
    private func generateEd25519KeyAndSignature() throws -> (Ed25519PublicKey, Ed25519Signature) {
        let privateKey = Ed25519PrivateKey.generate()
        let publicKey = privateKey.publicKey()
        let message = Data("authenticator test".utf8)
        let signature = try privateKey.sign(message: message)
        return (publicKey, signature)
    }

    // MARK: - AccountAuthenticator Ed25519 BCS Round-trip

    func testAccountAuthenticatorEd25519RoundTrip() throws {
        let (pk, sig) = try generateEd25519KeyAndSignature()
        let auth = AccountAuthenticator.ed25519(publicKey: pk, signature: sig)

        let serialized = auth.bcsToBytes()
        var d = Deserializer(data: serialized)
        let deserialized = try AccountAuthenticator.deserialize(from: &d)
        try d.assertFinished()

        guard case .ed25519(let dPK, let dSig) = deserialized else {
            XCTFail("Expected .ed25519 variant")
            return
        }
        XCTAssertEqual(dPK.data, pk.data)
        XCTAssertEqual(dSig.data, sig.data)
    }

    // MARK: - AccountAuthenticator SingleKey BCS Round-trip

    func testAccountAuthenticatorSingleKeyEd25519RoundTrip() throws {
        let (pk, sig) = try generateEd25519KeyAndSignature()
        let anyPK = AnyPublicKey.ed25519(pk)
        let anySig = AnySignature.ed25519(sig)
        let auth = AccountAuthenticator.singleKey(publicKey: anyPK, signature: anySig)

        let serialized = auth.bcsToBytes()
        var d = Deserializer(data: serialized)
        let deserialized = try AccountAuthenticator.deserialize(from: &d)
        try d.assertFinished()

        guard case .singleKey(let dPK, let dSig) = deserialized else {
            XCTFail("Expected .singleKey variant")
            return
        }
        XCTAssertEqual(dPK.data, pk.data)
        XCTAssertEqual(dSig.data, sig.data)
    }

    // MARK: - AccountAuthenticator noAccountAuthenticator Round-trip

    func testAccountAuthenticatorNoAuthRoundTrip() throws {
        let auth = AccountAuthenticator.noAccountAuthenticator

        let serialized = auth.bcsToBytes()
        var d = Deserializer(data: serialized)
        let deserialized = try AccountAuthenticator.deserialize(from: &d)
        try d.assertFinished()

        guard case .noAccountAuthenticator = deserialized else {
            XCTFail("Expected .noAccountAuthenticator variant")
            return
        }
    }

    // MARK: - AccountAuthenticator Variant Index

    func testAccountAuthenticatorEd25519VariantIndex() throws {
        let (pk, sig) = try generateEd25519KeyAndSignature()
        let auth = AccountAuthenticator.ed25519(publicKey: pk, signature: sig)
        let bytes = auth.bcsToBytes()
        // First byte is ULEB128 variant = 0
        XCTAssertEqual(bytes[0], 0x00)
    }

    func testAccountAuthenticatorSingleKeyVariantIndex() throws {
        let (pk, sig) = try generateEd25519KeyAndSignature()
        let anyPK = AnyPublicKey.ed25519(pk)
        let anySig = AnySignature.ed25519(sig)
        let auth = AccountAuthenticator.singleKey(publicKey: anyPK, signature: anySig)
        let bytes = auth.bcsToBytes()
        // Variant 2 for singleKey
        XCTAssertEqual(bytes[0], 0x02)
    }

    func testAccountAuthenticatorNoAuthVariantIndex() {
        let auth = AccountAuthenticator.noAccountAuthenticator
        let bytes = auth.bcsToBytes()
        // Variant 4 for noAccountAuthenticator
        XCTAssertEqual(bytes[0], 0x04)
    }

    // MARK: - TransactionAuthenticator Ed25519 BCS Round-trip

    func testTransactionAuthenticatorEd25519RoundTrip() throws {
        let (pk, sig) = try generateEd25519KeyAndSignature()
        let txAuth = TransactionAuthenticator.ed25519(publicKey: pk, signature: sig)

        let serialized = txAuth.bcsToBytes()
        var d = Deserializer(data: serialized)
        let deserialized = try TransactionAuthenticator.deserialize(from: &d)
        try d.assertFinished()

        guard case .ed25519(let dPK, let dSig) = deserialized else {
            XCTFail("Expected .ed25519 variant")
            return
        }
        XCTAssertEqual(dPK.data, pk.data)
        XCTAssertEqual(dSig.data, sig.data)
    }

    // MARK: - TransactionAuthenticator SingleSender BCS Round-trip

    func testTransactionAuthenticatorSingleSenderRoundTrip() throws {
        let (pk, sig) = try generateEd25519KeyAndSignature()
        let accountAuth = AccountAuthenticator.ed25519(publicKey: pk, signature: sig)
        let txAuth = TransactionAuthenticator.singleSender(accountAuth)

        let serialized = txAuth.bcsToBytes()
        var d = Deserializer(data: serialized)
        let deserialized = try TransactionAuthenticator.deserialize(from: &d)
        try d.assertFinished()

        guard case .singleSender(let innerAuth) = deserialized else {
            XCTFail("Expected .singleSender variant")
            return
        }
        guard case .ed25519(let dPK, let dSig) = innerAuth else {
            XCTFail("Expected inner .ed25519 variant")
            return
        }
        XCTAssertEqual(dPK.data, pk.data)
        XCTAssertEqual(dSig.data, sig.data)
    }

    // MARK: - TransactionAuthenticator Variant Indexes

    func testTransactionAuthenticatorEd25519VariantIndex() throws {
        let (pk, sig) = try generateEd25519KeyAndSignature()
        let txAuth = TransactionAuthenticator.ed25519(publicKey: pk, signature: sig)
        let bytes = txAuth.bcsToBytes()
        XCTAssertEqual(bytes[0], 0x00)
    }

    func testTransactionAuthenticatorSingleSenderVariantIndex() throws {
        let (pk, sig) = try generateEd25519KeyAndSignature()
        let accountAuth = AccountAuthenticator.ed25519(publicKey: pk, signature: sig)
        let txAuth = TransactionAuthenticator.singleSender(accountAuth)
        let bytes = txAuth.bcsToBytes()
        // Variant 4 for singleSender
        XCTAssertEqual(bytes[0], 0x04)
    }

    // MARK: - TransactionAuthenticator FeePayer BCS Round-trip

    func testFeePayerAuthenticatorRoundTrip() throws {
        let (pk, sig) = try generateEd25519KeyAndSignature()
        let senderAuth = AccountAuthenticator.ed25519(publicKey: pk, signature: sig)
        let feePayerAuth = AccountAuthenticator.noAccountAuthenticator

        let feePayer = FeePayerAuthenticator(
            senderAuthenticator: senderAuth,
            secondarySignerAddresses: [AccountAddress.THREE],
            secondaryAuthenticators: [AccountAuthenticator.noAccountAuthenticator],
            feePayerAddress: AccountAddress.FOUR,
            feePayerAuthenticator: feePayerAuth
        )

        let txAuth = TransactionAuthenticator.feePayer(feePayer)
        let serialized = txAuth.bcsToBytes()
        var d = Deserializer(data: serialized)
        let deserialized = try TransactionAuthenticator.deserialize(from: &d)
        try d.assertFinished()

        guard case .feePayer(let fp) = deserialized else {
            XCTFail("Expected .feePayer variant")
            return
        }

        // Verify sender authenticator
        guard case .ed25519(let fpPK, let fpSig) = fp.senderAuthenticator else {
            XCTFail("Expected sender .ed25519")
            return
        }
        XCTAssertEqual(fpPK.data, pk.data)
        XCTAssertEqual(fpSig.data, sig.data)

        // Verify secondary signers
        XCTAssertEqual(fp.secondarySignerAddresses, [AccountAddress.THREE])
        XCTAssertEqual(fp.secondaryAuthenticators.count, 1)
        guard case .noAccountAuthenticator = fp.secondaryAuthenticators[0] else {
            XCTFail("Expected noAccountAuthenticator")
            return
        }

        // Verify fee payer
        XCTAssertEqual(fp.feePayerAddress, AccountAddress.FOUR)
        guard case .noAccountAuthenticator = fp.feePayerAuthenticator else {
            XCTFail("Expected fee payer noAccountAuthenticator")
            return
        }
    }

    // MARK: - TransactionAuthenticator MultiAgent BCS Round-trip

    func testMultiAgentAuthenticatorRoundTrip() throws {
        let (pk, sig) = try generateEd25519KeyAndSignature()
        let senderAuth = AccountAuthenticator.ed25519(publicKey: pk, signature: sig)
        let secondaryAuth = AccountAuthenticator.noAccountAuthenticator

        let multiAgent = MultiAgentAuthenticator(
            senderAuthenticator: senderAuth,
            secondarySignerAddresses: [AccountAddress.ONE],
            secondaryAuthenticators: [secondaryAuth]
        )

        let txAuth = TransactionAuthenticator.multiAgent(multiAgent)
        let serialized = txAuth.bcsToBytes()
        var d = Deserializer(data: serialized)
        let deserialized = try TransactionAuthenticator.deserialize(from: &d)
        try d.assertFinished()

        guard case .multiAgent(let ma) = deserialized else {
            XCTFail("Expected .multiAgent variant")
            return
        }

        guard case .ed25519(let maPK, let maSig) = ma.senderAuthenticator else {
            XCTFail("Expected sender .ed25519")
            return
        }
        XCTAssertEqual(maPK.data, pk.data)
        XCTAssertEqual(maSig.data, sig.data)
        XCTAssertEqual(ma.secondarySignerAddresses, [AccountAddress.ONE])
        XCTAssertEqual(ma.secondaryAuthenticators.count, 1)
    }

    // MARK: - Unknown Variant Deserialization

    func testAccountAuthenticatorUnknownVariantThrows() {
        // Build raw bytes with variant = 99
        var s = Serializer()
        s.serializeU32AsUleb128(99)
        let bytes = s.output()
        var d = Deserializer(data: bytes)
        XCTAssertThrowsError(try AccountAuthenticator.deserialize(from: &d)) { error in
            guard case AptosError.deserializationError(let msg) = error else {
                XCTFail("Expected deserializationError, got: \(error)")
                return
            }
            XCTAssertTrue(msg.contains("Unknown AccountAuthenticator variant"))
        }
    }

    func testTransactionAuthenticatorUnknownVariantThrows() {
        var s = Serializer()
        s.serializeU32AsUleb128(99)
        let bytes = s.output()
        var d = Deserializer(data: bytes)
        XCTAssertThrowsError(try TransactionAuthenticator.deserialize(from: &d)) { error in
            guard case AptosError.deserializationError(let msg) = error else {
                XCTFail("Expected deserializationError, got: \(error)")
                return
            }
            XCTAssertTrue(msg.contains("Unknown TransactionAuthenticator variant"))
        }
    }

    // MARK: - AccountAuthenticator Hashable

    func testAccountAuthenticatorHashable() throws {
        let (pk, sig) = try generateEd25519KeyAndSignature()
        let auth1 = AccountAuthenticator.ed25519(publicKey: pk, signature: sig)
        let auth2 = AccountAuthenticator.ed25519(publicKey: pk, signature: sig)
        XCTAssertEqual(auth1, auth2)

        var set = Set<AccountAuthenticator>()
        set.insert(auth1)
        set.insert(auth2)
        XCTAssertEqual(set.count, 1)
    }

    // MARK: - TransactionAuthenticator Hashable

    func testTransactionAuthenticatorHashable() throws {
        let (pk, sig) = try generateEd25519KeyAndSignature()
        let txAuth1 = TransactionAuthenticator.ed25519(publicKey: pk, signature: sig)
        let txAuth2 = TransactionAuthenticator.ed25519(publicKey: pk, signature: sig)
        XCTAssertEqual(txAuth1, txAuth2)
    }

    // MARK: - Secp256k1 AccountAuthenticator via SingleKey

    func testAccountAuthenticatorSingleKeySecp256k1RoundTrip() throws {
        let privateKey = Secp256k1PrivateKey.generate()
        let publicKey = privateKey.publicKey()
        let message = Data("secp256k1 authenticator test".utf8)
        let signature = try privateKey.sign(message: message)

        let anyPK = AnyPublicKey.secp256k1(publicKey)
        let anySig = AnySignature.secp256k1(signature)
        let auth = AccountAuthenticator.singleKey(publicKey: anyPK, signature: anySig)

        let serialized = auth.bcsToBytes()
        var d = Deserializer(data: serialized)
        let deserialized = try AccountAuthenticator.deserialize(from: &d)
        try d.assertFinished()

        guard case .singleKey(let dPK, let dSig) = deserialized else {
            XCTFail("Expected .singleKey variant")
            return
        }
        XCTAssertEqual(dPK.data, publicKey.data)
        XCTAssertEqual(dSig.data, signature.data)
    }
}
