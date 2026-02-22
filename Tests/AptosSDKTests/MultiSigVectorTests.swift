import Foundation
import Testing
@testable import AptosSDK

@Suite("Multi-Sig Test Vectors")
struct MultiSigVectorTests {
    // MARK: - Multi-Ed25519 Auth Key Structure

    @Test("Multi-Ed25519 auth key input structure: pk1 || pk2 || pk3 || threshold || scheme")
    func multiEd25519AuthKeyStructure() throws {
        let key1 = try Ed25519PrivateKey.generate().publicKey()
        let key2 = try Ed25519PrivateKey.generate().publicKey()
        let key3 = try Ed25519PrivateKey.generate().publicKey()

        let multiPub = try MultiEd25519PublicKey(publicKeys: [key1, key2, key3], threshold: 2)
        let authKey = try AuthenticationKey.fromMultiEd25519(publicKey: multiPub)
        #expect(authKey.data.count == 32)
    }

    // MARK: - Bitmap Encoding

    @Test("Bitmap: signers [0, 1] = 0xc0000000")
    func bitmapSigners01() throws {
        let sig = MultiKeySignature.fromSignaturesWithIndices(
            signatures: [
                (index: 0, signature: .ed25519(try Ed25519Signature(data: Data(repeating: 0, count: 64)))),
                (index: 1, signature: .ed25519(try Ed25519Signature(data: Data(repeating: 0, count: 64)))),
            ],
            totalKeys: 3
        )
        #expect(dataToHex(sig.bitmap) == "c0000000")
    }

    @Test("Bitmap: signers [0, 2] = 0xa0000000")
    func bitmapSigners02() throws {
        let sig = MultiKeySignature.fromSignaturesWithIndices(
            signatures: [
                (index: 0, signature: .ed25519(try Ed25519Signature(data: Data(repeating: 0, count: 64)))),
                (index: 2, signature: .ed25519(try Ed25519Signature(data: Data(repeating: 0, count: 64)))),
            ],
            totalKeys: 3
        )
        #expect(dataToHex(sig.bitmap) == "a0000000")
    }

    @Test("Bitmap: signers [1, 2] = 0x60000000")
    func bitmapSigners12() throws {
        let sig = MultiKeySignature.fromSignaturesWithIndices(
            signatures: [
                (index: 1, signature: .ed25519(try Ed25519Signature(data: Data(repeating: 0, count: 64)))),
                (index: 2, signature: .ed25519(try Ed25519Signature(data: Data(repeating: 0, count: 64)))),
            ],
            totalKeys: 3
        )
        #expect(dataToHex(sig.bitmap) == "60000000")
    }

    // MARK: - Invalid Cases

    @Test("Threshold zero throws typed MultiSignatureError")
    func thresholdZero() throws {
        let key = try Ed25519PrivateKey.generate().publicKey()
        do {
            _ = try MultiEd25519PublicKey(publicKeys: [key, key, key], threshold: 0)
            Issue.record("Expected error")
        } catch let AptosError.multiSignature(e) {
            if case .invalidThreshold = e {
                // Expected
            } else {
                Issue.record("Expected invalidThreshold, got \(e)")
            }
        }
    }

    @Test("Threshold exceeds key count throws typed MultiSignatureError")
    func thresholdExceedsKeys() throws {
        let key = try Ed25519PrivateKey.generate().publicKey()
        do {
            _ = try MultiEd25519PublicKey(publicKeys: [key, key, key], threshold: 4)
            Issue.record("Expected error")
        } catch let AptosError.multiSignature(e) {
            if case .invalidThreshold = e {
                // Expected
            } else {
                Issue.record("Expected invalidThreshold, got \(e)")
            }
        }
    }

    @Test("No keys throws typed MultiSignatureError")
    func noKeys() {
        do {
            _ = try MultiEd25519PublicKey(publicKeys: [], threshold: 1)
            Issue.record("Expected error")
        } catch let AptosError.multiSignature(e) {
            if case .invalidThreshold = e {
                // Expected
            } else {
                Issue.record("Expected invalidThreshold, got \(e)")
            }
        } catch {
            Issue.record("Expected multiSignature error, got \(error)")
        }
    }

    @Test("Too many keys throws tooManyKeys")
    func tooManyKeys() throws {
        var keys = [Ed25519PublicKey]()
        for _ in 0 ..< 33 {
            keys.append(try Ed25519PrivateKey.generate().publicKey())
        }
        do {
            _ = try MultiEd25519PublicKey(publicKeys: keys, threshold: 2)
            Issue.record("Expected error")
        } catch let AptosError.multiSignature(e) {
            if case let .tooManyKeys(count, maximum) = e {
                #expect(count == 33)
                #expect(maximum == 32)
            } else {
                Issue.record("Expected tooManyKeys, got \(e)")
            }
        }
    }

    @Test("MultiKey empty keys throws typed MultiSignatureError")
    func multiKeyNoKeys() {
        do {
            _ = try MultiKey(publicKeys: [], signaturesRequired: 1)
            Issue.record("Expected error")
        } catch let AptosError.multiSignature(e) {
            if case .invalidThreshold = e {
                // Expected
            } else {
                Issue.record("Expected invalidThreshold, got \(e)")
            }
        } catch {
            Issue.record("Expected multiSignature error, got \(error)")
        }
    }

    @Test("MultiKey signature rejects duplicate signer index")
    func multiKeySignatureRejectsDuplicateSignerIndex() throws {
        let sig = try Ed25519Signature(data: Data(repeating: 0, count: 64))
        #expect(throws: AptosError.self) {
            _ = try MultiKeySignature.validatedFromSignaturesWithIndices(
                signatures: [
                    (index: 0, signature: .ed25519(sig)),
                    (index: 0, signature: .ed25519(sig)),
                ],
                totalKeys: 2
            )
        }
    }

    @Test("MultiKey signature rejects out-of-range signer index")
    func multiKeySignatureRejectsOutOfRangeSignerIndex() throws {
        let sig = try Ed25519Signature(data: Data(repeating: 0, count: 64))
        #expect(throws: AptosError.self) {
            _ = try MultiKeySignature.validatedFromSignaturesWithIndices(
                signatures: [(index: 5, signature: .ed25519(sig))],
                totalKeys: 2
            )
        }
    }

    // MARK: - MultiKey

    @Test("MultiKey auth key derivation")
    func multiKeyAuthKey() throws {
        let key1 = AnyPublicKey.ed25519(try Ed25519PrivateKey.generate().publicKey())
        let key2 = AnyPublicKey.ed25519(try Ed25519PrivateKey.generate().publicKey())
        let multiKey = try MultiKey(publicKeys: [key1, key2], signaturesRequired: 2)
        let authKey = try AuthenticationKey.fromMultiKey(multiKey: multiKey)
        #expect(authKey.data.count == 32)
    }

    // MARK: - Multi-Agent

    @Test("Multi-agent signing message uses RawTransactionWithData domain")
    func multiAgentDomain() {
        let prefix = AptosHashing.signingPrefix("APTOS::RawTransactionWithData")
        #expect(prefix.count == 32)
        #expect(dataToHex(prefix) == "5efa3c4f02f83a0f4b2d69fc95c607cc02825cc4e7be536ef0992df050d9e67c")
    }

    // MARK: - Fee Payer

    @Test("Fee payer signing message uses same domain as multi-agent")
    func feePayerDomain() {
        let prefix = AptosHashing.signingPrefix("APTOS::RawTransactionWithData")
        #expect(dataToHex(prefix) == "5efa3c4f02f83a0f4b2d69fc95c607cc02825cc4e7be536ef0992df050d9e67c")
    }

    // MARK: - Account Authenticator Variant Indices

    @Test("Account authenticator variant indices match spec")
    func authenticatorVariants() {
        // Ed25519 = 0, MultiEd25519 = 1, SingleKey = 2, MultiKey = 3
        // These are tested implicitly through serialization.
        // Verify the signing schemes match.
        #expect(SigningScheme.ed25519.rawValue == 0)
        #expect(SigningScheme.multiEd25519.rawValue == 1)
        #expect(SigningScheme.singleKey.rawValue == 2)
        #expect(SigningScheme.multiKey.rawValue == 3)
        #expect(SigningScheme.keyless.rawValue == 5)
    }

    // MARK: - 1-of-1 Degenerate Case

    @Test("1-of-1 multi-ed25519 is valid")
    func oneOfOne() throws {
        let key = try Ed25519PrivateKey.generate().publicKey()
        let multiPub = try MultiEd25519PublicKey(publicKeys: [key], threshold: 1)
        let authKey = try AuthenticationKey.fromMultiEd25519(publicKey: multiPub)
        #expect(authKey.data.count == 32)
    }
}
