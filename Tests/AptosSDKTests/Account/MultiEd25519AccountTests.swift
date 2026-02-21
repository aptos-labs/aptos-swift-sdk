import Foundation
import Testing
@testable import AptosSDK

@Suite("MultiEd25519Account Tests")
struct MultiEd25519AccountTests {
    // MARK: - Local Signing

    @Test("2-of-3 local signing creates multiEd25519 authenticator")
    func twoOfThreeLocalSigning() throws {
        let priv1 = Ed25519PrivateKey.generate()
        let priv2 = Ed25519PrivateKey.generate()
        let priv3 = Ed25519PrivateKey.generate()
        let pub1 = try priv1.publicKey()
        let pub2 = try priv2.publicKey()
        let pub3 = try priv3.publicKey()

        let multiPub = try MultiEd25519PublicKey(publicKeys: [pub1, pub2, pub3], threshold: 2)
        let account = try MultiEd25519Account(
            multiKey: multiPub,
            signers: [priv1, priv2],
            signerIndices: [0, 1]
        )

        let message = Data("test message".utf8)
        let auth = try account.signWithAuthenticator(message: message)

        if case let .multiEd25519(pubKey, sig) = auth {
            #expect(pubKey == multiPub)
            #expect(sig.signatures.count == 2)
            #expect(sig.bitmap.count == 4)
        } else {
            Issue.record("Expected multiEd25519 authenticator")
        }
    }

    // MARK: - Pre-collected Signatures

    @Test("Pre-collected signatures assemble correct bitmap")
    func preCollectedSignatures() throws {
        let priv1 = Ed25519PrivateKey.generate()
        let priv2 = Ed25519PrivateKey.generate()
        let priv3 = Ed25519PrivateKey.generate()
        let pub1 = try priv1.publicKey()
        let pub2 = try priv2.publicKey()
        let pub3 = try priv3.publicKey()

        let message = Data("test message".utf8)
        let sig1 = try priv1.sign(message)
        let sig3 = try priv3.sign(message)

        let multiPub = try MultiEd25519PublicKey(publicKeys: [pub1, pub2, pub3], threshold: 2)
        let account = try MultiEd25519Account(
            multiKey: multiPub,
            signatures: [sig1, sig3],
            signerIndices: [0, 2]
        )

        let multiSig = try account.signMultiEd25519(message: message)
        // Bitmap for indices 0, 2: bit 0 and bit 2 set = 0xa0000000
        #expect(dataToHex(multiSig.bitmap) == "a0000000")
        #expect(multiSig.signatures.count == 2)
    }

    // MARK: - Max Keys

    @Test("32-key max enforced: 33 keys throws tooManyKeys")
    func maxKeysEnforced() throws {
        var keys = [Ed25519PublicKey]()
        for _ in 0 ..< 33 {
            keys.append(try Ed25519PrivateKey.generate().publicKey())
        }

        #expect(throws: AptosError.self) {
            _ = try MultiEd25519PublicKey(publicKeys: keys, threshold: 2)
        }
    }

    @Test("32 keys is valid")
    func thirtyTwoKeysValid() throws {
        var keys = [Ed25519PublicKey]()
        for _ in 0 ..< 32 {
            keys.append(try Ed25519PrivateKey.generate().publicKey())
        }

        let multiPub = try MultiEd25519PublicKey(publicKeys: keys, threshold: 2)
        #expect(multiPub.publicKeys.count == 32)
    }

    // MARK: - Threshold Validation

    @Test("Threshold 0 throws")
    func thresholdZero() throws {
        let key = try Ed25519PrivateKey.generate().publicKey()
        #expect(throws: AptosError.self) {
            _ = try MultiEd25519PublicKey(publicKeys: [key, key, key], threshold: 0)
        }
    }

    @Test("Threshold greater than count throws")
    func thresholdExceedsCount() throws {
        let key = try Ed25519PrivateKey.generate().publicKey()
        #expect(throws: AptosError.self) {
            _ = try MultiEd25519PublicKey(publicKeys: [key, key, key], threshold: 4)
        }
    }

    // MARK: - Signer Index Validation

    @Test("Duplicate signer index rejected")
    func duplicateSignerIndex() throws {
        let priv1 = Ed25519PrivateKey.generate()
        let priv2 = Ed25519PrivateKey.generate()
        let pub1 = try priv1.publicKey()
        let pub2 = try priv2.publicKey()

        let multiPub = try MultiEd25519PublicKey(publicKeys: [pub1, pub2], threshold: 2)

        #expect(throws: AptosError.self) {
            _ = try MultiEd25519Account(
                multiKey: multiPub,
                signers: [priv1, priv2],
                signerIndices: [0, 0]
            )
        }
    }

    @Test("Invalid signer index rejected")
    func invalidSignerIndex() throws {
        let priv1 = Ed25519PrivateKey.generate()
        let priv2 = Ed25519PrivateKey.generate()
        let pub1 = try priv1.publicKey()
        let pub2 = try priv2.publicKey()

        let multiPub = try MultiEd25519PublicKey(publicKeys: [pub1, pub2], threshold: 2)

        #expect(throws: AptosError.self) {
            _ = try MultiEd25519Account(
                multiKey: multiPub,
                signers: [priv1, priv2],
                signerIndices: [0, 5]
            )
        }
    }

    // MARK: - Auth Key Derivation

    @Test("Auth key derivation matches address")
    func authKeyMatchesAddress() throws {
        let priv1 = Ed25519PrivateKey.generate()
        let priv2 = Ed25519PrivateKey.generate()
        let pub1 = try priv1.publicKey()
        let pub2 = try priv2.publicKey()

        let multiPub = try MultiEd25519PublicKey(publicKeys: [pub1, pub2], threshold: 2)
        let account = try MultiEd25519Account(
            multiKey: multiPub,
            signers: [priv1, priv2],
            signerIndices: [0, 1]
        )

        let authKey = try account.authenticationKey()
        let derived = authKey.accountAddress()
        #expect(derived == account.accountAddress)
    }

    @Test("Signing scheme is multiEd25519")
    func signingSchemeIsMultiEd25519() throws {
        let priv1 = Ed25519PrivateKey.generate()
        let priv2 = Ed25519PrivateKey.generate()
        let pub1 = try priv1.publicKey()
        let pub2 = try priv2.publicKey()

        let multiPub = try MultiEd25519PublicKey(publicKeys: [pub1, pub2], threshold: 2)
        let account = try MultiEd25519Account(
            multiKey: multiPub,
            signers: [priv1, priv2],
            signerIndices: [0, 1]
        )

        #expect(account.signingScheme == .multiEd25519)
    }
}
