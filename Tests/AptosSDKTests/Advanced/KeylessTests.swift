import Foundation
import Testing
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
        let expiry = UInt64(Date().timeIntervalSince1970) + 3600

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
            uidVal: "user123",
            audience: "test-client"
        )

        #expect(account.accountAddress.data.count == 32)
        #expect(account.signingScheme == .keyless)
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
            uidVal: "user456",
            audience: "test-client"
        )

        let account2 = try KeylessAccount(
            issuer: "https://accounts.google.com",
            ephemeralKeyPair: ekp2,
            proof: Data(repeating: 0, count: 64),
            jwt: "jwt2",
            pepper: pepper,
            uidKey: "sub",
            uidVal: "user456",
            audience: "test-client"
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
            uidVal: "user789",
            audience: "test-client"
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
            uidVal: "user000",
            audience: "test-client"
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

    // MARK: - Blinding Factor Tests

    @Test("New EphemeralKeyPair has 31-byte blinding factor")
    func blindingFactorGenerated() throws {
        let ekp = try EphemeralKeyPair()
        #expect(ekp.blindingFactor != nil)
        #expect(ekp.blindingFactor?.count == 31)
    }

    @Test("Nonce with blinding factor differs from nonce without")
    func nonceWithBlindingFactorDiffers() throws {
        let privKey = Ed25519PrivateKey.generate()
        let expiry = UInt64(Date().timeIntervalSince1970) + 3600

        let ekpWithBlinding = try EphemeralKeyPair(
            privateKey: privKey,
            expiryDateSecs: expiry,
            blindingFactor: Data(repeating: 0x42, count: 31)
        )
        let ekpWithout = try EphemeralKeyPair(
            privateKey: privKey,
            expiryDateSecs: expiry,
            blindingFactor: nil
        )

        #expect(ekpWithBlinding.nonce != ekpWithout.nonce)
    }

    @Test("EphemeralKeyPair BCS roundtrip with blinding factor")
    func ephemeralBCSRoundtripWithBlinding() throws {
        let ekp = try EphemeralKeyPair()
        let data = try bcsToBytes(ekp)
        let decoded = try bcsFromBytes(EphemeralKeyPair.self, data)
        #expect(decoded.privateKey == ekp.privateKey)
        #expect(decoded.expiryDateSecs == ekp.expiryDateSecs)
        #expect(decoded.blindingFactor == ekp.blindingFactor)
        #expect(decoded.nonce == ekp.nonce)
    }

    // MARK: - Proof Expiry Tests

    @Test("isProofExpired false when no expiry set")
    func proofNotExpiredNoExpiry() throws {
        let ekp = try EphemeralKeyPair()
        let account = try KeylessAccount(
            issuer: "https://accounts.google.com",
            ephemeralKeyPair: ekp,
            proof: Data(repeating: 0, count: 64),
            jwt: "test",
            pepper: Data(repeating: 0x03, count: 31),
            uidVal: "user000",
            audience: "test-client"
        )
        #expect(!account.isProofExpired)
    }

    @Test("isProofExpired true when past expiry")
    func proofExpiredPastExpiry() throws {
        let ekp = try EphemeralKeyPair()
        let pastExpiry = UInt64(Date().timeIntervalSince1970) - 100
        let account = try KeylessAccount(
            issuer: "https://accounts.google.com",
            ephemeralKeyPair: ekp,
            proof: Data(repeating: 0, count: 64),
            jwt: "test",
            pepper: Data(repeating: 0x03, count: 31),
            uidVal: "user000",
            audience: "test-client",
            proofExpiryDateSecs: pastExpiry
        )
        #expect(account.isProofExpired)
    }

    @Test("isExpired checks both ephemeral key and proof")
    func isExpiredChecksBoth() throws {
        let ekp = try EphemeralKeyPair()
        let futureExpiry = UInt64(Date().timeIntervalSince1970) + 7200
        let account = try KeylessAccount(
            issuer: "https://accounts.google.com",
            ephemeralKeyPair: ekp,
            proof: Data(repeating: 0, count: 64),
            jwt: "test",
            pepper: Data(repeating: 0x03, count: 31),
            uidVal: "user000",
            audience: "test-client",
            proofExpiryDateSecs: futureExpiry
        )
        // Neither ephemeral key nor proof expired
        #expect(!account.isExpired)
    }

    @Test("sign() throws on expired proof")
    func signThrowsOnExpiredProof() throws {
        let ekp = try EphemeralKeyPair()
        let pastExpiry = UInt64(Date().timeIntervalSince1970) - 100
        let account = try KeylessAccount(
            issuer: "https://accounts.google.com",
            ephemeralKeyPair: ekp,
            proof: Data(repeating: 0, count: 64),
            jwt: "test",
            pepper: Data(repeating: 0x03, count: 31),
            uidVal: "user000",
            audience: "test-client",
            proofExpiryDateSecs: pastExpiry
        )

        #expect(throws: AptosError.self) {
            _ = try account.sign(message: Data("test".utf8))
        }
    }

    @Test("JWT expiry extraction works")
    func jwtExpiryExtraction() throws {
        // Create a JWT with exp claim: {"alg":"none"}.{"sub":"user","exp":1000000}.
        let header = Data(#"{"alg":"none"}"#.utf8).base64EncodedString()
        let payload = Data(#"{"sub":"user","exp":1000000}"#.utf8).base64EncodedString()
        let jwt = "\(header).\(payload).sig"

        let ekp = try EphemeralKeyPair()
        let account = try KeylessAccount(
            issuer: "https://accounts.google.com",
            ephemeralKeyPair: ekp,
            proof: Data(repeating: 0, count: 64),
            jwt: jwt,
            pepper: Data(repeating: 0x03, count: 31),
            uidVal: "user000",
            audience: "test-client"
        )

        // exp=1000000 is far in the past, so JWT should be expired
        #expect(account.isJWTExpired)
    }

    @Test("sign() throws on expired JWT")
    func signThrowsOnExpiredJWT() throws {
        let header = Data(#"{"alg":"none"}"#.utf8).base64EncodedString()
        let payload = Data(#"{"sub":"user","exp":1000000}"#.utf8).base64EncodedString()
        let jwt = "\(header).\(payload).sig"

        let ekp = try EphemeralKeyPair()
        let account = try KeylessAccount(
            issuer: "https://accounts.google.com",
            ephemeralKeyPair: ekp,
            proof: Data(repeating: 0, count: 64),
            jwt: jwt,
            pepper: Data(repeating: 0x03, count: 31),
            uidVal: "user000",
            audience: "test-client"
        )

        #expect(account.isJWTExpired)
        #expect(throws: AptosError.self) {
            _ = try account.sign(message: Data("test".utf8))
        }
    }

    @Test("Keyless account creation fails when audience is missing")
    func keylessAccountCreationMissingAudienceThrows() throws {
        let ekp = try EphemeralKeyPair()
        #expect(throws: AptosError.self) {
            _ = try KeylessAccount(
                issuer: "https://accounts.google.com",
                ephemeralKeyPair: ekp,
                proof: Data(repeating: 0, count: 64),
                jwt: "invalid.jwt",
                pepper: Data(repeating: 0x03, count: 31),
                uidVal: "user000"
            )
        }
    }

    @Test("Keyless account creation fails for invalid pepper length")
    func keylessAccountCreationInvalidPepperLengthThrows() throws {
        let ekp = try EphemeralKeyPair()
        #expect(throws: AptosError.self) {
            _ = try KeylessAccount(
                issuer: "https://accounts.google.com",
                ephemeralKeyPair: ekp,
                proof: Data(repeating: 0, count: 64),
                jwt: "invalid.jwt",
                pepper: Data(repeating: 0x03, count: 30),
                uidVal: "user000",
                audience: "test-client"
            )
        }
    }

    @Test("Keyless account creation fails for empty explicit audience")
    func keylessAccountCreationEmptyExplicitAudienceThrows() throws {
        let ekp = try EphemeralKeyPair()
        #expect(throws: AptosError.self) {
            _ = try KeylessAccount(
                issuer: "https://accounts.google.com",
                ephemeralKeyPair: ekp,
                proof: Data(repeating: 0, count: 64),
                jwt: "invalid.jwt",
                pepper: Data(repeating: 0x03, count: 31),
                uidVal: "user000",
                audience: ""
            )
        }
    }
}
