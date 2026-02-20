import Testing
import Foundation
@testable import AptosSDK

@Suite("Account Tests")
struct AccountTests {
    @Test("Generate Ed25519 account")
    func generateEd25519() throws {
        let account = try Ed25519Account.generate()
        #expect(account.accountAddress.data.count == 32)
        #expect(account.signingScheme == .ed25519)
    }

    @Test("Ed25519 account sign and verify")
    func ed25519SignVerify() throws {
        let account = try Ed25519Account.generate()
        let message = Data("test".utf8)
        let sig = try account.sign(message: message)

        if case .ed25519(let ed25519Sig) = sig {
            let valid = account.publicKey.verify(message: message, signature: ed25519Sig)
            #expect(valid)
        } else {
            Issue.record("Expected Ed25519 signature")
        }
    }

    @Test("Ed25519 account from private key")
    func ed25519FromPrivateKey() throws {
        let privKey = Ed25519PrivateKey.generate()
        let account1 = try Ed25519Account(privateKey: privKey)
        let account2 = try Ed25519Account(privateKey: privKey)
        #expect(account1.accountAddress == account2.accountAddress)
    }

    @Test("SingleKey account (Ed25519)")
    func singleKeyEd25519() throws {
        let account = try SingleKeyAccount.generate(scheme: .ed25519)
        #expect(account.signingScheme == .singleKey)

        let message = Data("test".utf8)
        let sig = try account.sign(message: message)
        if case .ed25519 = sig {
            // Expected
        } else {
            Issue.record("Expected Ed25519 signature from SingleKey account")
        }
    }

    @Test("SingleKey account (Secp256k1)")
    func singleKeySecp256k1() throws {
        let account = try SingleKeyAccount.generate(scheme: .secp256k1Ecdsa)
        #expect(account.signingScheme == .singleKey)

        let message = Data("test".utf8)
        let sig = try account.sign(message: message)
        if case .secp256k1 = sig {
            // Expected
        } else {
            Issue.record("Expected Secp256k1 signature from SingleKey account")
        }
    }

    @Test("Account authenticator generation")
    func authenticatorGeneration() throws {
        let account = try Ed25519Account.generate()
        let message = Data("test".utf8)
        let auth = try account.signWithAuthenticator(message: message)

        if case .ed25519(let pubKey, let sig) = auth {
            #expect(pubKey == account.publicKey)
            let valid = pubKey.verify(message: message, signature: sig)
            #expect(valid)
        } else {
            Issue.record("Expected Ed25519 authenticator")
        }
    }

    @Test("Authentication key derivation matches address")
    func authKeyMatchesAddress() throws {
        let account = try Ed25519Account.generate()
        let authKey = try account.authenticationKey()
        let derived = authKey.accountAddress()
        #expect(derived == account.accountAddress)
    }
}
