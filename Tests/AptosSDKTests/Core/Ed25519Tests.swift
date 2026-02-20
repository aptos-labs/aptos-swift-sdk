import Foundation
import XCTest

@testable import AptosSDK

final class Ed25519Tests: XCTestCase {

    // MARK: - Key Generation

    func testGenerateProducesValidKey() {
        let privateKey = Ed25519PrivateKey.generate()
        XCTAssertEqual(privateKey.data.count, 32)
    }

    func testGenerateProducesDifferentKeys() {
        let key1 = Ed25519PrivateKey.generate()
        let key2 = Ed25519PrivateKey.generate()
        XCTAssertNotEqual(key1.data, key2.data)
    }

    func testPublicKeyDerivation() {
        let privateKey = Ed25519PrivateKey.generate()
        let publicKey = privateKey.publicKey()
        XCTAssertEqual(publicKey.data.count, Ed25519PublicKey.length)
    }

    func testPublicKeyIsDeterministic() {
        let privateKey = Ed25519PrivateKey.generate()
        let pk1 = privateKey.publicKey()
        let pk2 = privateKey.publicKey()
        XCTAssertEqual(pk1.data, pk2.data)
    }

    // MARK: - Private Key from Data

    func testPrivateKeyFromData() throws {
        let key = Ed25519PrivateKey.generate()
        let restored = try Ed25519PrivateKey(data: key.data)
        XCTAssertEqual(restored.data, key.data)
        // Derived public keys should match
        XCTAssertEqual(restored.publicKey().data, key.publicKey().data)
    }

    func testPrivateKeyFromInvalidLength() {
        XCTAssertThrowsError(try Ed25519PrivateKey(data: Data(repeating: 0, count: 16))) { error in
            guard case AptosError.invalidArgument = error else {
                XCTFail("Expected invalidArgument error")
                return
            }
        }
    }

    // MARK: - Private Key from Hex String

    func testPrivateKeyFromHexString() throws {
        let key = Ed25519PrivateKey.generate()
        let hexString = Hex.encode(key.data)
        let restored = try Ed25519PrivateKey(hexString: hexString)
        XCTAssertEqual(restored.data, key.data)
    }

    // MARK: - AIP-80 Format

    func testPrivateKeyToAIP80String() {
        let key = Ed25519PrivateKey.generate()
        let aip80 = key.toAIP80String()
        XCTAssertTrue(aip80.hasPrefix("ed25519-priv-0x"))
    }

    func testPrivateKeyFromAIP80String() throws {
        let key = Ed25519PrivateKey.generate()
        let aip80 = key.toAIP80String()
        let restored = try Ed25519PrivateKey(aip80String: aip80)
        XCTAssertEqual(restored.data, key.data)
    }

    func testPrivateKeyFromInvalidAIP80Prefix() {
        XCTAssertThrowsError(try Ed25519PrivateKey(aip80String: "secp256k1-priv-0x00"))
    }

    // MARK: - Sign and Verify

    func testSignAndVerify() throws {
        let privateKey = Ed25519PrivateKey.generate()
        let publicKey = privateKey.publicKey()
        let message = Data("test message".utf8)

        let signature = try privateKey.sign(message: message)
        XCTAssertEqual(signature.data.count, Ed25519Signature.length)

        let isValid = try publicKey.verify(message: message, signature: signature)
        XCTAssertTrue(isValid)
    }

    func testSignAndVerifyEmptyMessage() throws {
        let privateKey = Ed25519PrivateKey.generate()
        let publicKey = privateKey.publicKey()
        let message = Data()

        let signature = try privateKey.sign(message: message)
        let isValid = try publicKey.verify(message: message, signature: signature)
        XCTAssertTrue(isValid)
    }

    func testSignAndVerifyLargeMessage() throws {
        let privateKey = Ed25519PrivateKey.generate()
        let publicKey = privateKey.publicKey()
        let message = Data(repeating: 0xAB, count: 10_000)

        let signature = try privateKey.sign(message: message)
        let isValid = try publicKey.verify(message: message, signature: signature)
        XCTAssertTrue(isValid)
    }

    func testSignatureIsDeterministic() throws {
        let privateKey = Ed25519PrivateKey.generate()
        let message = Data("deterministic check".utf8)

        let sig1 = try privateKey.sign(message: message)
        let sig2 = try privateKey.sign(message: message)
        // Ed25519 signatures are deterministic
        XCTAssertEqual(sig1.data, sig2.data)
    }

    // MARK: - Invalid Signature Verification

    func testVerifyWithWrongMessage() throws {
        let privateKey = Ed25519PrivateKey.generate()
        let publicKey = privateKey.publicKey()
        let message = Data("original".utf8)
        let wrongMessage = Data("tampered".utf8)

        let signature = try privateKey.sign(message: message)
        let isValid = try publicKey.verify(message: wrongMessage, signature: signature)
        XCTAssertFalse(isValid)
    }

    func testVerifyWithWrongKey() throws {
        let key1 = Ed25519PrivateKey.generate()
        let key2 = Ed25519PrivateKey.generate()
        let message = Data("test".utf8)

        let signature = try key1.sign(message: message)
        let isValid = try key2.publicKey().verify(message: message, signature: signature)
        XCTAssertFalse(isValid)
    }

    func testVerifyWithCorruptedSignature() throws {
        let privateKey = Ed25519PrivateKey.generate()
        let publicKey = privateKey.publicKey()
        let message = Data("test".utf8)

        let signature = try privateKey.sign(message: message)
        // Corrupt the signature by flipping a byte
        var corruptedData = signature.data
        corruptedData[0] ^= 0xFF
        let corruptedSig = try Ed25519Signature(data: corruptedData)

        let isValid = try publicKey.verify(message: message, signature: corruptedSig)
        XCTAssertFalse(isValid)
    }

    // MARK: - Signature Construction

    func testSignatureFromData() throws {
        let data = Data(repeating: 0xAB, count: 64)
        let sig = try Ed25519Signature(data: data)
        XCTAssertEqual(sig.data, data)
    }

    func testSignatureFromInvalidLength() {
        XCTAssertThrowsError(try Ed25519Signature(data: Data(repeating: 0, count: 32))) { error in
            guard case AptosError.invalidArgument = error else {
                XCTFail("Expected invalidArgument error, got: \(error)")
                return
            }
        }
    }

    func testSignatureFromHexString() throws {
        let hexData = Data(repeating: 0xCD, count: 64)
        let hexString = Hex.encode(hexData)
        let sig = try Ed25519Signature(hexString: hexString)
        XCTAssertEqual(sig.data, hexData)
    }

    // MARK: - Public Key Construction

    func testPublicKeyFromData() throws {
        let privateKey = Ed25519PrivateKey.generate()
        let originalPK = privateKey.publicKey()
        let restoredPK = try Ed25519PublicKey(data: originalPK.data)
        XCTAssertEqual(restoredPK.data, originalPK.data)
    }

    func testPublicKeyFromHexString() throws {
        let privateKey = Ed25519PrivateKey.generate()
        let originalPK = privateKey.publicKey()
        let hexString = Hex.encode(originalPK.data)
        let restoredPK = try Ed25519PublicKey(hexString: hexString)
        XCTAssertEqual(restoredPK.data, originalPK.data)
    }

    func testPublicKeyFromInvalidLength() {
        XCTAssertThrowsError(try Ed25519PublicKey(data: Data(repeating: 0, count: 16)))
    }

    // MARK: - BCS Round-trip for Public Key

    func testPublicKeyBcsRoundTrip() throws {
        let privateKey = Ed25519PrivateKey.generate()
        let originalPK = privateKey.publicKey()

        let serialized = originalPK.bcsToBytes()
        var d = Deserializer(data: serialized)
        let deserialized = try Ed25519PublicKey.deserialize(from: &d)
        try d.assertFinished()

        XCTAssertEqual(deserialized.data, originalPK.data)
    }

    // MARK: - BCS Round-trip for Signature

    func testSignatureBcsRoundTrip() throws {
        let privateKey = Ed25519PrivateKey.generate()
        let message = Data("bcs round-trip test".utf8)
        let signature = try privateKey.sign(message: message)

        let serialized = signature.bcsToBytes()
        var d = Deserializer(data: serialized)
        let deserialized = try Ed25519Signature.deserialize(from: &d)
        try d.assertFinished()

        XCTAssertEqual(deserialized.data, signature.data)
    }

    // MARK: - Equatable / Hashable

    func testPublicKeyEquality() throws {
        let privateKey = Ed25519PrivateKey.generate()
        let pk1 = privateKey.publicKey()
        let pk2 = try Ed25519PublicKey(data: pk1.data)
        XCTAssertEqual(pk1, pk2)
    }

    func testPublicKeyHashable() throws {
        let key1 = Ed25519PrivateKey.generate()
        let pk = key1.publicKey()
        let pk2 = try Ed25519PublicKey(data: pk.data)
        var set = Set<Ed25519PublicKey>()
        set.insert(pk)
        set.insert(pk2)
        XCTAssertEqual(set.count, 1)
    }

    func testSignatureEquality() throws {
        let data = Data(repeating: 0xAA, count: 64)
        let sig1 = try Ed25519Signature(data: data)
        let sig2 = try Ed25519Signature(data: data)
        XCTAssertEqual(sig1, sig2)
    }

    // MARK: - CustomStringConvertible

    func testPublicKeyDescription() {
        let privateKey = Ed25519PrivateKey.generate()
        let pk = privateKey.publicKey()
        let desc = pk.description
        XCTAssertTrue(desc.hasPrefix("0x"))
        // 32 bytes -> 64 hex chars + "0x" prefix
        XCTAssertEqual(desc.count, 66)
    }

    func testSignatureDescription() throws {
        let sig = try Ed25519Signature(data: Data(repeating: 0, count: 64))
        let desc = sig.description
        XCTAssertTrue(desc.hasPrefix("0x"))
        // 64 bytes -> 128 hex chars + "0x" prefix
        XCTAssertEqual(desc.count, 130)
    }

    // MARK: - Public Key Codable

    func testPublicKeyCodableRoundTrip() throws {
        let privateKey = Ed25519PrivateKey.generate()
        let originalPK = privateKey.publicKey()

        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(originalPK)
        let decoder = JSONDecoder()
        let decodedPK = try decoder.decode(Ed25519PublicKey.self, from: jsonData)

        XCTAssertEqual(decodedPK.data, originalPK.data)
    }
}
