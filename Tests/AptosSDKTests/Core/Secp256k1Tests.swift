import Testing
import Foundation
@testable import AptosSDK

@Suite("Secp256k1 Tests")
struct Secp256k1Tests {
    @Test("Generate key pair")
    func generateKeyPair() throws {
        let privKey = Secp256k1PrivateKey.generate()
        #expect(privKey.data.count == 32)

        let pubKey = try privKey.publicKey()
        #expect(pubKey.data.count == 33) // Compressed
    }

    @Test("Sign and verify")
    func signAndVerify() throws {
        let privKey = Secp256k1PrivateKey.generate()
        let pubKey = try privKey.publicKey()

        let message = Data("test message".utf8)
        let sig = try privKey.sign(message)
        #expect(sig.data.count == 64)

        let valid = pubKey.verify(message: message, signature: sig)
        #expect(valid)
    }

    @Test("AIP-80 format")
    func aip80Format() throws {
        let privKey = Secp256k1PrivateKey.generate()
        let aip80 = privKey.toAIP80()
        #expect(aip80.hasPrefix("secp256k1-priv-"))

        let restored = try Secp256k1PrivateKey.fromAIP80(aip80)
        #expect(restored.data == privKey.data)
    }

    @Test("Invalid key length throws")
    func invalidKeyLength() throws {
        #expect(throws: AptosError.self) {
            try Secp256k1PrivateKey(data: Data(repeating: 0, count: 16))
        }
    }

    @Test("BCS roundtrip for public key")
    func bcsRoundtripPublicKey() throws {
        let privKey = Secp256k1PrivateKey.generate()
        let pubKey = try privKey.publicKey()

        let data = try bcsToBytes(pubKey)
        let decoded = try bcsFromBytes(Secp256k1PublicKey.self, data)
        #expect(decoded == pubKey)
    }
}
