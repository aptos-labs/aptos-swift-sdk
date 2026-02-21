import CryptoKit
import Foundation
import Testing
@testable import AptosSDK

@Suite("WebAuthn Tests")
struct WebAuthnTests {
    @Test("Parse clientDataJSON extracts fields")
    func parseClientDataJSON() throws {
        let challenge = Data("test-challenge".utf8)
        let challengeB64 = challenge.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")

        let json = """
        {"type":"webauthn.get","challenge":"\(challengeB64)","origin":"https://example.com"}
        """
        let clientData = try WebAuthnUtils.parseClientDataJSON(Data(json.utf8))
        #expect(clientData.type == "webauthn.get")
        #expect(clientData.origin == "https://example.com")
        #expect(clientData.challenge == challenge)
    }

    @Test("Parse throws on missing fields")
    func parseThrowsOnMissingFields() {
        let json = Data(#"{"type":"webauthn.get"}"#.utf8)
        #expect(throws: AptosError.self) {
            _ = try WebAuthnUtils.parseClientDataJSON(json)
        }
    }

    @Test("Verify WebAuthn signature with P-256 test data")
    func verifyWebAuthnSignature() throws {
        // Generate a P-256 key pair
        let privKey = P256.Signing.PrivateKey()
        let pubKeyData = Data(privKey.publicKey.x963Representation)
        let secp256r1PubKey = try Secp256r1PublicKey(data: pubKeyData)

        // Create test authenticatorData and clientDataJSON
        let authenticatorData = Data(repeating: 0xAB, count: 37)
        let clientDataJSON = Data(#"{"type":"webauthn.get","challenge":"dGVzdA","origin":"https://example.com"}"#.utf8)

        // Compute the message that WebAuthn signs: authenticatorData || SHA-256(clientDataJSON)
        let clientDataHash = Data(CryptoKit.SHA256.hash(data: clientDataJSON))
        var message = authenticatorData
        message.append(clientDataHash)

        // Sign with P-256 (CryptoKit hashes with SHA-256 internally)
        let ecdsaSig = try privKey.signature(for: message)
        let secp256r1Sig = try Secp256r1Signature(data: Data(ecdsaSig.rawRepresentation))

        // Verify using our helper
        let valid = WebAuthnUtils.verifyWebAuthnSignature(
            publicKey: secp256r1PubKey,
            signature: secp256r1Sig,
            authenticatorData: authenticatorData,
            clientDataJSON: clientDataJSON
        )
        #expect(valid)
    }

    @Test("Verify WebAuthn signature fails with wrong key")
    func verifyFailsWithWrongKey() throws {
        let privKey = P256.Signing.PrivateKey()
        let wrongKey = P256.Signing.PrivateKey()
        let wrongPubKeyData = Data(wrongKey.publicKey.x963Representation)
        let secp256r1WrongPubKey = try Secp256r1PublicKey(data: wrongPubKeyData)

        let authenticatorData = Data(repeating: 0xAB, count: 37)
        let clientDataJSON = Data(#"{"type":"webauthn.get","challenge":"dGVzdA","origin":"https://example.com"}"#.utf8)

        let clientDataHash = Data(CryptoKit.SHA256.hash(data: clientDataJSON))
        var message = authenticatorData
        message.append(clientDataHash)

        let ecdsaSig = try privKey.signature(for: message)
        let secp256r1Sig = try Secp256r1Signature(data: Data(ecdsaSig.rawRepresentation))

        let valid = WebAuthnUtils.verifyWebAuthnSignature(
            publicKey: secp256r1WrongPubKey,
            signature: secp256r1Sig,
            authenticatorData: authenticatorData,
            clientDataJSON: clientDataJSON
        )
        #expect(!valid)
    }
}
