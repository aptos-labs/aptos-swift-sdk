import Foundation
import Testing
@testable import AptosSDK

@Suite("Signature Test Vectors")
struct SignatureVectorTests {
    // MARK: - Ed25519 Key Derivation

    @Test("Ed25519 key from seed 1")
    func ed25519KeyFromSeed1() throws {
        let seedHex = "0000000000000000000000000000000000000000000000000000000000000001"
        let privKey = try Ed25519PrivateKey(data: hexToData(seedHex))
        let pubKey = try privKey.publicKey()
        #expect(dataToHex(pubKey.data) == "4cb5abf6ad79fbf5abbccafcc269d85cd2651ed4b885b5869f241aedf0a5ba29")
        #expect(pubKey.data.count == 32)
    }

    @Test("Ed25519 key from mnemonic-derived seed")
    func ed25519KeyFromRandomSeed() throws {
        let seedHex = "cc92c0eaf80206d817f150e21917f797e49cf644a33ac514de3c316baa2f1bf5"
        let privKey = try Ed25519PrivateKey(data: hexToData(seedHex))
        let pubKey = try privKey.publicKey()
        #expect(dataToHex(pubKey.data) == "a686f0309ab80312979606cfccc10ea2740147ae6888351488d11c46f08fbf60")
    }

    // MARK: - Ed25519 Deterministic Signing

    @Test("Ed25519 sign 'hello'")
    func ed25519SignHello() throws {
        let privKey =
            try Ed25519PrivateKey(data: hexToData("0000000000000000000000000000000000000000000000000000000000000001"))
        let message = Data("hello".utf8)
        let sig = try privKey.sign(message)
        #expect(sig.data.count == 64)
        #expect(dataToHex(sig.data) ==
            "c6cb9b70e0ee28cea926c251aa06b131b51dcdc52b6cc05df6235a56478852a5c3f737b12c3f4fca6e020c714100e712c1c22cb0402e9ef446aa2669831a9106")
    }

    @Test("Ed25519 sign empty message")
    func ed25519SignEmpty() throws {
        let privKey =
            try Ed25519PrivateKey(data: hexToData("0000000000000000000000000000000000000000000000000000000000000001"))
        let message = Data()
        let sig = try privKey.sign(message)
        #expect(sig.data.count == 64)
        #expect(dataToHex(sig.data) ==
            "7e1b9dc1e332c4238edcd07a68101474b640fdcb1b7b84fb711ac4bfbc85eb85a77480950d69398dcd19f61e1ea74d0f183cfbf34df8f6e7733ebfb9f944f106")
    }

    @Test("Ed25519 sign long message")
    func ed25519SignLong() throws {
        let privKey =
            try Ed25519PrivateKey(data: hexToData("0000000000000000000000000000000000000000000000000000000000000001"))
        let message = Data("The quick brown fox jumps over the lazy dog".utf8)
        let sig = try privKey.sign(message)
        #expect(sig.data.count == 64)
        #expect(dataToHex(sig.data) ==
            "b22f61ee39fca21a76bc01e6fedae2648e727020dcb092cc76af83aa9ea6f0876f843114f100bc1a0fb17be126cdb31438fbd9b0cb1583b6d00fcf31842b3d0c")
    }

    // MARK: - Ed25519 Verification

    @Test("Ed25519 verify valid signature")
    func ed25519VerifyValid() throws {
        let pubKey =
            try Ed25519PublicKey(data: hexToData("4cb5abf6ad79fbf5abbccafcc269d85cd2651ed4b885b5869f241aedf0a5ba29"))
        let message = Data("hello".utf8)
        let sig =
            try Ed25519Signature(
                data: hexToData(
                    "c6cb9b70e0ee28cea926c251aa06b131b51dcdc52b6cc05df6235a56478852a5c3f737b12c3f4fca6e020c714100e712c1c22cb0402e9ef446aa2669831a9106"
                )
            )
        #expect(pubKey.verify(message: message, signature: sig))
    }

    // MARK: - Secp256k1 Key Derivation

    @Test("Secp256k1 key from private key 1")
    func secp256k1Key() throws {
        let privKey =
            try Secp256k1PrivateKey(data: hexToData("0000000000000000000000000000000000000000000000000000000000000001"))
        let pubKey = try privKey.publicKey()
        #expect(pubKey.data.count == 33) // compressed
    }

    // MARK: - Secp256k1 Signing

    @Test("Secp256k1 deterministic signing")
    func secp256k1Sign() throws {
        let privKey =
            try Secp256k1PrivateKey(data: hexToData("0000000000000000000000000000000000000000000000000000000000000001"))
        let message = Data("hello".utf8)
        let sig = try privKey.sign(message)
        #expect(sig.data.count == 64)
    }

    // MARK: - Authentication Key Derivation

    @Test("Ed25519 authentication key derivation")
    func ed25519AuthKey() throws {
        let pubKeyHex = "a686f0309ab80312979606cfccc10ea2740147ae6888351488d11c46f08fbf60"
        let pubKey = try Ed25519PublicKey(data: hexToData(pubKeyHex))
        let authKey = AuthenticationKey.fromEd25519(publicKey: pubKey)
        #expect(dataToHex(authKey.data) == "eb663b681209e7087d681c5d3eed12aaa8e1915e7c87794542c3f96e94b3d3bf")
    }

    // MARK: - SHA3-256 Hashing

    @Test("SHA3-256 empty input")
    func sha3Empty() {
        let hash = AptosHashing.sha3_256(Data())
        #expect(dataToHex(hash) == "a7ffc6f8bf1ed76651c14756a061d662f580ff4de43b49fa82d80a4b80f8434a")
    }

    @Test("SHA3-256 hello")
    func sha3Hello() {
        let hash = AptosHashing.sha3_256(Data("hello".utf8))
        #expect(dataToHex(hash) == "3338be694f50c5f338814986cdf0686453a888b84f424d792af4b9202398f392")
    }

    @Test("SHA3-256 hello world")
    func sha3HelloWorld() {
        let hash = AptosHashing.sha3_256(Data("hello world".utf8))
        #expect(dataToHex(hash) == "644bcc7e564373040999aac89e7622f3ca71fba1d972fd94a31c3bfbf24e3938")
    }

    @Test("SHA3-256 single zero byte")
    func sha3SingleByte() {
        let hash = AptosHashing.sha3_256(Data([0x00]))
        #expect(dataToHex(hash) == "5d53469f20fef4f8eab52b88044ede69c77a6a68a60728609fc4a65ff531e7d0")
    }

    @Test("SHA3-256 32 zero bytes")
    func sha3_32Zeros() {
        let hash = AptosHashing.sha3_256(Data(repeating: 0, count: 32))
        #expect(dataToHex(hash) == "9e6291970cb44dd94008c79bcaf9d86f18b4b49ba5b2a04781db7199ed3b9e4e")
    }

    // MARK: - SHA2-256 Hashing

    @Test("SHA2-256 empty input")
    func sha2Empty() {
        let hash = AptosHashing.sha2_256(Data())
        #expect(dataToHex(hash) == "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
    }

    @Test("SHA2-256 hello")
    func sha2Hello() {
        let hash = AptosHashing.sha2_256(Data("hello".utf8))
        #expect(dataToHex(hash) == "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824")
    }

    @Test("SHA2-256 hello world")
    func sha2HelloWorld() {
        let hash = AptosHashing.sha2_256(Data("hello world".utf8))
        #expect(dataToHex(hash) == "b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9")
    }

    // MARK: - Domain Separators

    @Test("RawTransaction domain prefix")
    func rawTxnDomain() {
        let prefix = AptosHashing.signingPrefix("APTOS::RawTransaction")
        #expect(dataToHex(prefix) == "b5e97db07fa0bd0e5598aa3643a9bc6f6693bddc1a9fec9e674a461eaa00b193")
    }

    @Test("RawTransactionWithData domain prefix")
    func rawTxnWithDataDomain() {
        let prefix = AptosHashing.signingPrefix("APTOS::RawTransactionWithData")
        #expect(dataToHex(prefix) == "5efa3c4f02f83a0f4b2d69fc95c607cc02825cc4e7be536ef0992df050d9e67c")
    }

    @Test("Transaction domain prefix")
    func transactionDomain() {
        let prefix = AptosHashing.signingPrefix("APTOS::Transaction")
        #expect(dataToHex(prefix) == "fa210a9417ef3e7fa45bfa1d17a8dbd4d883711910a550d265fee189e9266dd4")
    }
}
