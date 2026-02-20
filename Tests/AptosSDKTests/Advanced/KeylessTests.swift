import Testing
import Foundation
@testable import AptosSDK

@Suite("Keyless Tests")
struct KeylessTests {
    @Test("Create ephemeral key pair")
    func createEphemeralKeyPair() throws {
        let ekp = try EphemeralKeyPair()
        #expect(ekp.publicKey.data.count == 32)
        #expect(!ekp.isExpired)
        #expect(!ekp.nonce.isEmpty)
    }

    @Test("Ephemeral key pair signs message")
    func ephemeralKeyPairSign() throws {
        let ekp = try EphemeralKeyPair()
        let message = Data("test message".utf8)
        let sig = try ekp.sign(message)
        #expect(sig.data.count == 64)
    }

    @Test("Ephemeral key pair nonce is deterministic")
    func ephemeralNonceDeterministic() throws {
        let privKey = Ed25519PrivateKey.generate()
        let expiry: UInt64 = UInt64(Date().timeIntervalSince1970) + 3600

        let ekp1 = try EphemeralKeyPair(privateKey: privKey, expiryDateSecs: expiry)
        let ekp2 = try EphemeralKeyPair(privateKey: privKey, expiryDateSecs: expiry)

        #expect(ekp1.nonce == ekp2.nonce)
    }

    @Test("Ephemeral key pair BCS roundtrip")
    func ephemeralBCSRoundtrip() throws {
        let ekp = try EphemeralKeyPair()
        let data = try bcsToBytes(ekp)
        let decoded = try bcsFromBytes(EphemeralKeyPair.self, data)
        #expect(decoded.privateKey == ekp.privateKey)
        #expect(decoded.expiryDateSecs == ekp.expiryDateSecs)
    }

    @Test("Keyless account creation")
    func keylessAccountCreation() throws {
        let ekp = try EphemeralKeyPair()

        let account = try KeylessAccount(
            issuer: "https://accounts.google.com",
            ephemeralKeyPair: ekp,
            proof: Data(repeating: 0xAB, count: 64),
            jwt: "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.test",
            pepper: Data(repeating: 0x01, count: 31),
            uidKey: "sub",
            uidVal: "user123"
        )

        #expect(account.accountAddress.data.count == 32)
        #expect(account.signingScheme == .singleKey)
        #expect(!account.isExpired)
    }

    @Test("Keyless account address is deterministic")
    func keylessAddressDeterministic() throws {
        let ekp1 = try EphemeralKeyPair()
        let ekp2 = try EphemeralKeyPair()

        let pepper = Data(repeating: 0x42, count: 31)

        let account1 = try KeylessAccount(
            issuer: "https://accounts.google.com",
            ephemeralKeyPair: ekp1,
            proof: Data(repeating: 0, count: 64),
            jwt: "jwt1",
            pepper: pepper,
            uidKey: "sub",
            uidVal: "user456"
        )

        let account2 = try KeylessAccount(
            issuer: "https://accounts.google.com",
            ephemeralKeyPair: ekp2,
            proof: Data(repeating: 0, count: 64),
            jwt: "jwt2",
            pepper: pepper,
            uidKey: "sub",
            uidVal: "user456"
        )

        // Same issuer + pepper + uid → same address, regardless of ephemeral key
        #expect(account1.accountAddress == account2.accountAddress)
    }

    @Test("Keyless account can sign")
    func keylessAccountSign() throws {
        let ekp = try EphemeralKeyPair()

        let account = try KeylessAccount(
            issuer: "https://accounts.google.com",
            ephemeralKeyPair: ekp,
            proof: Data(repeating: 0xCD, count: 64),
            jwt: "test.jwt",
            pepper: Data(repeating: 0x02, count: 31),
            uidVal: "user789"
        )

        let message = Data("test transaction".utf8)
        let sig = try account.sign(message: message)

        if case .keyless = sig {
            // Expected keyless signature
        } else {
            Issue.record("Expected keyless signature")
        }
    }

    @Test("Keyless account authentication key matches address")
    func keylessAuthKeyMatchesAddress() throws {
        let ekp = try EphemeralKeyPair()

        let account = try KeylessAccount(
            issuer: "https://accounts.google.com",
            ephemeralKeyPair: ekp,
            proof: Data(repeating: 0, count: 64),
            jwt: "test",
            pepper: Data(repeating: 0x03, count: 31),
            uidVal: "user000"
        )

        let authKey = try account.authenticationKey()
        let derived = authKey.accountAddress()
        #expect(derived == account.accountAddress)
    }

    @Test("Keyless public key BCS roundtrip")
    func keylessPublicKeyBCS() throws {
        let pubKey = KeylessPublicKey(
            issuer: "https://accounts.google.com",
            idCommitment: Data(repeating: 0xAA, count: 32)
        )

        let data = try bcsToBytes(pubKey)
        let decoded = try bcsFromBytes(KeylessPublicKey.self, data)
        #expect(decoded == pubKey)
    }
}
