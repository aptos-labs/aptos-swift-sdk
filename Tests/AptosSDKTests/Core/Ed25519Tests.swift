import Foundation
import Testing
@testable import AptosSDK

@Suite("Ed25519 Tests")
struct Ed25519Tests {
    @Test("Generate key pair")
    func generateKeyPair() throws {
        let privKey = Ed25519PrivateKey.generate()
        #expect(privKey.data.count == 32)

        let pubKey = try privKey.publicKey()
        #expect(pubKey.data.count == 32)
    }

    @Test("Sign and verify")
    func signAndVerify() throws {
        let privKey = Ed25519PrivateKey.generate()
        let pubKey = try privKey.publicKey()

        let message = Data("test message".utf8)
        let sig = try privKey.sign(message)
        #expect(sig.data.count == 64)

        let valid = pubKey.verify(message: message, signature: sig)
        #expect(valid)
    }

    @Test("Invalid message fails verification")
    func invalidMessage() throws {
        let privKey = Ed25519PrivateKey.generate()
        let pubKey = try privKey.publicKey()

        let message = Data("test message".utf8)
        let sig = try privKey.sign(message)

        let wrongMessage = Data("wrong message".utf8)
        let valid = pubKey.verify(message: wrongMessage, signature: sig)
        #expect(!valid)
    }

    @Test("From hex roundtrip")
    func hexRoundtrip() throws {
        let privKey = Ed25519PrivateKey.generate()
        let hex = Hex.encode(privKey.data)
        let restored = try Ed25519PrivateKey.fromHex(hex)
        #expect(restored.data == privKey.data)
    }

    @Test("AIP-80 format")
    func aip80Format() throws {
        let privKey = Ed25519PrivateKey.generate()
        let aip80 = privKey.toAIP80()
        #expect(aip80.hasPrefix("ed25519-priv-"))

        let restored = try Ed25519PrivateKey.fromAIP80(aip80)
        #expect(restored.data == privKey.data)
    }

    @Test("Invalid key length throws")
    func invalidKeyLength() throws {
        #expect(throws: AptosError.self) {
            try Ed25519PublicKey(data: Data(repeating: 0, count: 16))
        }
    }

    @Test("BCS roundtrip for public key")
    func bcsRoundtripPublicKey() throws {
        let privKey = Ed25519PrivateKey.generate()
        let pubKey = try privKey.publicKey()

        let data = try bcsToBytes(pubKey)
        let decoded = try bcsFromBytes(Ed25519PublicKey.self, data)
        #expect(decoded == pubKey)
    }

    @Test("Authentication key derivation")
    func authKeyDerivation() throws {
        let privKey = Ed25519PrivateKey.generate()
        let pubKey = try privKey.publicKey()

        let authKey = AuthenticationKey.fromEd25519(publicKey: pubKey)
        #expect(authKey.data.count == 32)

        let address = authKey.accountAddress()
        #expect(address.data.count == 32)
    }
}
