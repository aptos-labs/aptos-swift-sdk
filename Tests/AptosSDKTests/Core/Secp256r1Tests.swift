import Testing
import Foundation
@testable import AptosSDK

@Suite("Secp256r1 Tests")
struct Secp256r1Tests {
    @Test("Generate key pair")
    func generateKeyPair() throws {
        let privKey = Secp256r1PrivateKey.generate()
        #expect(privKey.data.count == 32)

        let pubKey = try privKey.publicKey()
        #expect(pubKey.data.count == 65) // Uncompressed P-256
    }

    @Test("Sign and verify")
    func signAndVerify() throws {
        let privKey = Secp256r1PrivateKey.generate()
        let pubKey = try privKey.publicKey()

        let message = Data("test message".utf8)
        let sig = try privKey.sign(message)
        #expect(sig.data.count == 64)

        let valid = pubKey.verify(message: message, signature: sig)
        #expect(valid)
    }

    @Test("Invalid message fails verification")
    func invalidMessage() throws {
        let privKey = Secp256r1PrivateKey.generate()
        let pubKey = try privKey.publicKey()

        let message = Data("test message".utf8)
        let sig = try privKey.sign(message)

        let wrongMessage = Data("wrong message".utf8)
        let valid = pubKey.verify(message: wrongMessage, signature: sig)
        #expect(!valid)
    }

    @Test("AIP-80 format")
    func aip80Format() throws {
        let privKey = Secp256r1PrivateKey.generate()
        let aip80 = privKey.toAIP80()
        #expect(aip80.hasPrefix("secp256r1-priv-"))

        let restored = try Secp256r1PrivateKey.fromAIP80(aip80)
        #expect(restored.data == privKey.data)
    }

    @Test("Invalid key length throws")
    func invalidKeyLength() throws {
        #expect(throws: AptosError.self) {
            try Secp256r1PrivateKey(data: Data(repeating: 0, count: 16))
        }
    }

    @Test("BCS roundtrip for public key")
    func bcsRoundtripPublicKey() throws {
        let privKey = Secp256r1PrivateKey.generate()
        let pubKey = try privKey.publicKey()

        let data = try bcsToBytes(pubKey)
        let decoded = try bcsFromBytes(Secp256r1PublicKey.self, data)
        #expect(decoded == pubKey)
    }

    @Test("Compressed public key input")
    func compressedPublicKeyInput() throws {
        let privKey = Secp256r1PrivateKey.generate()
        let pubKey = try privKey.publicKey()

        // Get compressed form (first 33 bytes: 0x02 or 0x03 + x coordinate)
        let uncompressedData = pubKey.data
        var compressed = Data()
        let yLastByte = uncompressedData[uncompressedData.count - 1]
        compressed.append(yLastByte % 2 == 0 ? 0x02 : 0x03)
        compressed.append(uncompressedData[1..<33]) // x coordinate

        // Should accept compressed format
        let fromCompressed = try Secp256r1PublicKey(data: compressed)
        // The stored data should be uncompressed
        #expect(fromCompressed.data.count == 65)
    }
}
