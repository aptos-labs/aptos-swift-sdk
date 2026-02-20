import Foundation
import XCTest

@testable import AptosSDK

final class Secp256k1Tests: XCTestCase {

    // MARK: - Key Generation

    func testGenerateProducesValidKey() {
        let privateKey = Secp256k1PrivateKey.generate()
        XCTAssertEqual(privateKey.data.count, 32)
    }

    func testGenerateProducesDifferentKeys() {
        let key1 = Secp256k1PrivateKey.generate()
        let key2 = Secp256k1PrivateKey.generate()
        XCTAssertNotEqual(key1.data, key2.data)
    }

    func testPublicKeyDerivation() {
        let privateKey = Secp256k1PrivateKey.generate()
        let publicKey = privateKey.publicKey()
        // Uncompressed public key: 65 bytes (04 || X || Y)
        XCTAssertEqual(publicKey.data.count, 65)
        XCTAssertEqual(publicKey.data[0], 0x04)
    }

    func testPublicKeyIsDeterministic() {
        let privateKey = Secp256k1PrivateKey.generate()
        let pk1 = privateKey.publicKey()
        let pk2 = privateKey.publicKey()
        XCTAssertEqual(pk1.data, pk2.data)
    }

    // MARK: - Private Key from Data

    func testPrivateKeyFromData() throws {
        let key = Secp256k1PrivateKey.generate()
        let restored = try Secp256k1PrivateKey(key.data)
        XCTAssertEqual(restored.data, key.data)
        XCTAssertEqual(restored.publicKey().data, key.publicKey().data)
    }

    func testPrivateKeyFromInvalidLength() {
        XCTAssertThrowsError(try Secp256k1PrivateKey(Data(repeating: 0, count: 16))) { error in
            guard case AptosError.cryptoError = error else {
                XCTFail("Expected cryptoError, got: \(error)")
                return
            }
        }
    }

    // MARK: - Private Key from Hex String

    func testPrivateKeyFromHexString() throws {
        let key = Secp256k1PrivateKey.generate()
        let hexString = Hex.encode(key.data)
        let restored = try Secp256k1PrivateKey(hexString: hexString)
        XCTAssertEqual(restored.data, key.data)
    }

    // MARK: - AIP-80 Format

    func testPrivateKeyToAIP80String() {
        let key = Secp256k1PrivateKey.generate()
        let aip80 = key.toAIP80String()
        XCTAssertTrue(aip80.hasPrefix("secp256k1-priv-0x"))
    }

    func testPrivateKeyFromAIP80String() throws {
        let key = Secp256k1PrivateKey.generate()
        let aip80 = key.toAIP80String()
        let restored = try Secp256k1PrivateKey(aip80: aip80)
        XCTAssertEqual(restored.data, key.data)
    }

    func testPrivateKeyFromInvalidAIP80Prefix() {
        XCTAssertThrowsError(try Secp256k1PrivateKey(aip80: "ed25519-priv-0x00"))
    }

    // MARK: - Sign and Verify

    func testSignAndVerify() throws {
        let privateKey = Secp256k1PrivateKey.generate()
        let publicKey = privateKey.publicKey()
        let message = Data("test message for secp256k1".utf8)

        let signature = try privateKey.sign(message: message)
        XCTAssertEqual(signature.data.count, 64)

        let isValid = try publicKey.verify(message: message, signature: signature)
        XCTAssertTrue(isValid)
    }

    func testSignAndVerifyEmptyMessage() throws {
        let privateKey = Secp256k1PrivateKey.generate()
        let publicKey = privateKey.publicKey()
        let message = Data()

        let signature = try privateKey.sign(message: message)
        let isValid = try publicKey.verify(message: message, signature: signature)
        XCTAssertTrue(isValid)
    }

    // MARK: - Invalid Signature Verification

    func testVerifyWithWrongMessage() throws {
        let privateKey = Secp256k1PrivateKey.generate()
        let publicKey = privateKey.publicKey()
        let message = Data("original".utf8)
        let wrongMessage = Data("tampered".utf8)

        let signature = try privateKey.sign(message: message)
        let isValid = try publicKey.verify(message: wrongMessage, signature: signature)
        XCTAssertFalse(isValid)
    }

    func testVerifyWithWrongKey() throws {
        let key1 = Secp256k1PrivateKey.generate()
        let key2 = Secp256k1PrivateKey.generate()
        let message = Data("test".utf8)

        let signature = try key1.sign(message: message)
        let isValid = try key2.publicKey().verify(message: message, signature: signature)
        XCTAssertFalse(isValid)
    }

    // MARK: - Compressed vs Uncompressed Public Key

    func testUncompressedPublicKeyCreation() throws {
        let privateKey = Secp256k1PrivateKey.generate()
        let uncompressed = privateKey.publicKey()
        XCTAssertEqual(uncompressed.data.count, 65)
        XCTAssertEqual(uncompressed.data[0], 0x04, "Uncompressed key must start with 0x04")
    }

    func testCompressedPublicKeyCreation() throws {
        let privateKey = Secp256k1PrivateKey.generate()
        // Get the underlying P256K key for compressed form
        let p256kKey = try P256K.Signing.PrivateKey(dataRepresentation: privateKey.data)
        let compressedBytes = Data(p256kKey.publicKey.dataRepresentation)
        XCTAssertEqual(compressedBytes.count, 33)
        let prefix = compressedBytes[0]
        XCTAssertTrue(prefix == 0x02 || prefix == 0x03, "Compressed key must start with 0x02 or 0x03")

        // Construct Secp256k1PublicKey from compressed and verify it decompresses
        let pubKey = try Secp256k1PublicKey(compressedBytes)
        XCTAssertEqual(pubKey.data.count, 65, "Should store as uncompressed internally")
        XCTAssertEqual(pubKey.data[0], 0x04)
    }

    func testCompressedAndUncompressedGiveSameKey() throws {
        let privateKey = Secp256k1PrivateKey.generate()
        let uncompressedPK = privateKey.publicKey()

        // Get compressed form
        let p256kKey = try P256K.Signing.PrivateKey(dataRepresentation: privateKey.data)
        let compressedBytes = Data(p256kKey.publicKey.dataRepresentation)

        let fromCompressed = try Secp256k1PublicKey(compressedBytes)
        XCTAssertEqual(fromCompressed.data, uncompressedPK.data)
    }

    func testInvalidPublicKeyLength() {
        XCTAssertThrowsError(try Secp256k1PublicKey(Data(repeating: 0, count: 20)))
    }

    func testInvalidUncompressedPrefix() {
        // 65 bytes but wrong prefix
        var badKey = Data(repeating: 0x01, count: 65)
        badKey[0] = 0x05  // not 0x04
        XCTAssertThrowsError(try Secp256k1PublicKey(badKey))
    }

    func testInvalidCompressedPrefix() {
        // 33 bytes but wrong prefix
        var badKey = Data(repeating: 0x01, count: 33)
        badKey[0] = 0x05  // not 0x02 or 0x03
        XCTAssertThrowsError(try Secp256k1PublicKey(badKey))
    }

    // MARK: - BCS Round-trip for Public Key

    func testPublicKeyBcsRoundTrip() throws {
        let privateKey = Secp256k1PrivateKey.generate()
        let originalPK = privateKey.publicKey()

        let serialized = originalPK.bcsToBytes()
        var d = Deserializer(data: serialized)
        let deserialized = try Secp256k1PublicKey.deserialize(from: &d)
        try d.assertFinished()

        XCTAssertEqual(deserialized.data, originalPK.data)
    }

    // MARK: - BCS Round-trip for Signature

    func testSignatureBcsRoundTrip() throws {
        let privateKey = Secp256k1PrivateKey.generate()
        let message = Data("bcs round-trip test".utf8)
        let signature = try privateKey.sign(message: message)

        let serialized = signature.bcsToBytes()
        var d = Deserializer(data: serialized)
        let deserialized = try Secp256k1Signature.deserialize(from: &d)
        try d.assertFinished()

        XCTAssertEqual(deserialized.data, signature.data)
    }

    // MARK: - Signature Construction

    func testSignatureFromData() throws {
        let data = Data(repeating: 0xAB, count: 64)
        let sig = try Secp256k1Signature(data)
        XCTAssertEqual(sig.data, data)
    }

    func testSignatureFromInvalidLength() {
        XCTAssertThrowsError(try Secp256k1Signature(Data(repeating: 0, count: 32)))
    }

    func testSignatureFromHexString() throws {
        let hexData = Data(repeating: 0xCD, count: 64)
        let hexString = Hex.encode(hexData)
        let sig = try Secp256k1Signature(hexString: hexString)
        XCTAssertEqual(sig.data, hexData)
    }

    // MARK: - Equatable / Hashable

    func testPublicKeyEquality() throws {
        let privateKey = Secp256k1PrivateKey.generate()
        let pk1 = privateKey.publicKey()
        let pk2 = try Secp256k1PublicKey(pk1.data)
        XCTAssertEqual(pk1, pk2)
    }

    func testPublicKeyHashable() throws {
        let privateKey = Secp256k1PrivateKey.generate()
        let pk1 = privateKey.publicKey()
        let pk2 = try Secp256k1PublicKey(pk1.data)
        var set = Set<Secp256k1PublicKey>()
        set.insert(pk1)
        set.insert(pk2)
        XCTAssertEqual(set.count, 1)
    }

    func testSignatureEquality() throws {
        let data = Data(repeating: 0xAA, count: 64)
        let sig1 = try Secp256k1Signature(data)
        let sig2 = try Secp256k1Signature(data)
        XCTAssertEqual(sig1, sig2)
    }

    // MARK: - CustomStringConvertible

    func testPublicKeyDescription() {
        let privateKey = Secp256k1PrivateKey.generate()
        let pk = privateKey.publicKey()
        let desc = pk.description
        XCTAssertTrue(desc.hasPrefix("0x"))
        // 65 bytes -> 130 hex chars + "0x" prefix
        XCTAssertEqual(desc.count, 132)
    }

    func testPrivateKeyDescriptionRedacted() {
        let key = Secp256k1PrivateKey.generate()
        let desc = key.description
        XCTAssertTrue(desc.contains("redacted"))
    }
}
