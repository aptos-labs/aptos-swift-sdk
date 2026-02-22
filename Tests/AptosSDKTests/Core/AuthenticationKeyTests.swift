import Foundation
import Testing
@testable import AptosSDK

@Suite("AuthenticationKey Tests")
struct AuthenticationKeyTests {
    @Test("Ed25519 authentication key derivation")
    func ed25519AuthKey() throws {
        let privKey = Ed25519PrivateKey.generate()
        let pubKey = try privKey.publicKey()

        let authKey = AuthenticationKey.fromEd25519(publicKey: pubKey)
        #expect(authKey.data.count == 32)
    }

    @Test("Same public key produces same authentication key")
    func deterministicAuthKey() throws {
        let privKey = Ed25519PrivateKey.generate()
        let pubKey = try privKey.publicKey()

        let authKey1 = AuthenticationKey.fromEd25519(publicKey: pubKey)
        let authKey2 = AuthenticationKey.fromEd25519(publicKey: pubKey)
        #expect(authKey1 == authKey2)
    }

    @Test("Different public keys produce different authentication keys")
    func differentKeysProduceDifferentAuthKeys() throws {
        let pubKey1 = try Ed25519PrivateKey.generate().publicKey()
        let pubKey2 = try Ed25519PrivateKey.generate().publicKey()

        let authKey1 = AuthenticationKey.fromEd25519(publicKey: pubKey1)
        let authKey2 = AuthenticationKey.fromEd25519(publicKey: pubKey2)
        #expect(authKey1 != authKey2)
    }

    @Test("Account address derivation from authentication key")
    func addressDerivation() throws {
        let privKey = Ed25519PrivateKey.generate()
        let pubKey = try privKey.publicKey()

        let authKey = AuthenticationKey.fromEd25519(publicKey: pubKey)
        let address = authKey.accountAddress()
        #expect(address.data.count == 32)
        #expect(address.data == authKey.data)
    }

    @Test("SingleKey authentication key differs from Ed25519")
    func singleKeyDiffersFromEd25519() throws {
        let privKey = Ed25519PrivateKey.generate()
        let pubKey = try privKey.publicKey()

        let ed25519AuthKey = AuthenticationKey.fromEd25519(publicKey: pubKey)
        let singleKeyAuthKey = try AuthenticationKey.fromSingleKey(publicKey: .ed25519(pubKey))

        // Different schemes → different auth keys
        #expect(ed25519AuthKey != singleKeyAuthKey)
    }

    @Test("MultiKey authentication key")
    func multiKeyAuthKey() throws {
        let pubKey1 = try Ed25519PrivateKey.generate().publicKey()
        let pubKey2 = try Ed25519PrivateKey.generate().publicKey()

        let multiKey = try MultiKey(
            publicKeys: [.ed25519(pubKey1), .ed25519(pubKey2)],
            signaturesRequired: 1
        )

        let authKey = try AuthenticationKey.fromMultiKey(multiKey: multiKey)
        #expect(authKey.data.count == 32)
    }

    @Test("fromSingleKey rejects keyless keys")
    func fromSingleKeyRejectsKeyless() throws {
        let keylessPublicKey = KeylessPublicKey(
            issuer: "https://accounts.google.com",
            idCommitment: Data(repeating: 1, count: 32)
        )
        #expect(throws: AptosError.self) {
            _ = try AuthenticationKey.fromSingleKey(publicKey: .keyless(keylessPublicKey))
        }
    }

    @Test("Keyless authentication key derivation is deterministic")
    func keylessAuthKeyDeterministic() throws {
        let authKey1 = try AuthenticationKey.fromKeyless(
            issuer: "https://accounts.google.com",
            audience: "my-client-id",
            uidKey: "sub",
            uidVal: "user123",
            pepper: Data(repeating: 0xAB, count: 31)
        )
        let authKey2 = try AuthenticationKey.fromKeyless(
            issuer: "https://accounts.google.com",
            audience: "my-client-id",
            uidKey: "sub",
            uidVal: "user123",
            pepper: Data(repeating: 0xAB, count: 31)
        )
        #expect(authKey1 == authKey2)
        #expect(authKey1.data.count == 32)
    }

    @Test("Keyless authentication key requires 31-byte pepper")
    func keylessAuthKeyPepperLengthValidation() throws {
        #expect(throws: AptosError.self) {
            _ = try AuthenticationKey.fromKeyless(
                issuer: "https://accounts.google.com",
                audience: "my-client-id",
                uidKey: "sub",
                uidVal: "user123",
                pepper: Data(repeating: 0xAB, count: 30)
            )
        }
    }

    @Test("Authentication key hex roundtrip")
    func hexRoundtrip() throws {
        let privKey = Ed25519PrivateKey.generate()
        let pubKey = try privKey.publicKey()

        let authKey = AuthenticationKey.fromEd25519(publicKey: pubKey)
        let hex = authKey.toHex()
        #expect(hex.hasPrefix("0x"))
        #expect(hex.count == 66) // "0x" + 64 hex chars
    }

    @Test("Invalid authentication key length throws")
    func invalidLengthThrows() throws {
        #expect(throws: AptosError.self) {
            try AuthenticationKey(data: Data(repeating: 0, count: 16))
        }
    }
}
