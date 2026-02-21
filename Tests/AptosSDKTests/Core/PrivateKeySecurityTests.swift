import Foundation
import Testing
@testable import AptosSDK

@Suite("Private Key Security Tests")
struct PrivateKeySecurityTests {
    // MARK: - Ed25519 Log Safety

    @Test("Ed25519PrivateKey description is redacted")
    func ed25519Description() {
        let key = Ed25519PrivateKey.generate()
        let desc = String(describing: key)
        #expect(desc.contains("REDACTED"))
        #expect(!desc.contains(Hex.encodeWithoutPrefix(key.data)))
    }

    @Test("Ed25519PrivateKey debugDescription is redacted")
    func ed25519DebugDescription() {
        let key = Ed25519PrivateKey.generate()
        let desc = String(reflecting: key)
        #expect(desc.contains("REDACTED"))
    }

    @Test("Ed25519PrivateKey zeroize clears data")
    func ed25519Zeroize() {
        var key = Ed25519PrivateKey.generate()
        #expect(key.data != Data(repeating: 0, count: 32))
        key.zeroize()
        #expect(key.data == Data(repeating: 0, count: 32))
    }

    // MARK: - Secp256k1 Log Safety

    @Test("Secp256k1PrivateKey description is redacted")
    func secp256k1Description() {
        let key = Secp256k1PrivateKey.generate()
        let desc = String(describing: key)
        #expect(desc.contains("REDACTED"))
        #expect(!desc.contains(Hex.encodeWithoutPrefix(key.data)))
    }

    @Test("Secp256k1PrivateKey debugDescription is redacted")
    func secp256k1DebugDescription() {
        let key = Secp256k1PrivateKey.generate()
        let desc = String(reflecting: key)
        #expect(desc.contains("REDACTED"))
    }

    @Test("Secp256k1PrivateKey zeroize clears data")
    func secp256k1Zeroize() {
        var key = Secp256k1PrivateKey.generate()
        #expect(key.data != Data(repeating: 0, count: 32))
        key.zeroize()
        #expect(key.data == Data(repeating: 0, count: 32))
    }

    // MARK: - Secp256r1 Log Safety

    @Test("Secp256r1PrivateKey description is redacted")
    func secp256r1Description() {
        let key = Secp256r1PrivateKey.generate()
        let desc = String(describing: key)
        #expect(desc.contains("REDACTED"))
        #expect(!desc.contains(Hex.encodeWithoutPrefix(key.data)))
    }

    @Test("Secp256r1PrivateKey debugDescription is redacted")
    func secp256r1DebugDescription() {
        let key = Secp256r1PrivateKey.generate()
        let desc = String(reflecting: key)
        #expect(desc.contains("REDACTED"))
    }

    @Test("Secp256r1PrivateKey zeroize clears data")
    func secp256r1Zeroize() {
        var key = Secp256r1PrivateKey.generate()
        #expect(key.data != Data(repeating: 0, count: 32))
        key.zeroize()
        #expect(key.data == Data(repeating: 0, count: 32))
    }
}
