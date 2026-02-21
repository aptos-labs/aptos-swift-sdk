import Foundation
import Testing
@testable import AptosSDK

@Suite("Mnemonic Test Vectors")
struct MnemonicVectorTests {
    static let standardMnemonic =
        "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about"

    // MARK: - BIP-39 Seed Derivation

    @Test("Standard 12-word mnemonic produces correct seed")
    func standardSeed() throws {
        let seed = try Mnemonic.toSeed(Self.standardMnemonic, passphrase: "")
        #expect(seed.count == 64)
        #expect(dataToHex(seed) ==
            "5eb00bbddcf069084889a8ab9155568165f5c453ccb85e70811aaed6f6da5fc19a5ac40b389cd370d086206dec8aa6c43daea6690f20ad3d8d48b2d2ce9e38e4")
    }

    // MARK: - Ed25519 Key Derivation from Mnemonic

    @Test("Standard 12-word mnemonic default path derivation")
    func ed25519DefaultPath() throws {
        let account = try Ed25519Account.fromMnemonic(Self.standardMnemonic)

        // Check private key
        let privKeyHex = dataToHex(account.privateKey.data)
        #expect(privKeyHex == "cc92c0eaf80206d817f150e21917f797e49cf644a33ac514de3c316baa2f1bf5")

        // Check public key
        #expect(dataToHex(account.publicKey.data) == "a686f0309ab80312979606cfccc10ea2740147ae6888351488d11c46f08fbf60")

        // Check address
        #expect(account.accountAddress.toHex() == "0xeb663b681209e7087d681c5d3eed12aaa8e1915e7c87794542c3f96e94b3d3bf")
    }

    // MARK: - Authentication Key from Public Key

    @Test("Authentication key derivation from public key")
    func authKeyDerivation() throws {
        let pubKey =
            try Ed25519PublicKey(data: hexToData("a686f0309ab80312979606cfccc10ea2740147ae6888351488d11c46f08fbf60"))
        let authKey = AuthenticationKey.fromEd25519(publicKey: pubKey)
        #expect(dataToHex(authKey.data) == "eb663b681209e7087d681c5d3eed12aaa8e1915e7c87794542c3f96e94b3d3bf")
    }

    @Test("Auth key derives correct address")
    func authKeyAddress() throws {
        let pubKey =
            try Ed25519PublicKey(data: hexToData("a686f0309ab80312979606cfccc10ea2740147ae6888351488d11c46f08fbf60"))
        let authKey = AuthenticationKey.fromEd25519(publicKey: pubKey)
        let addr = authKey.accountAddress()
        #expect(addr.toHex() == "0xeb663b681209e7087d681c5d3eed12aaa8e1915e7c87794542c3f96e94b3d3bf")
    }

    // MARK: - Different Indices Produce Different Addresses

    @Test("Different derivation indices produce different addresses")
    func differentIndices() throws {
        let account0 = try Ed25519Account.fromMnemonic(Self.standardMnemonic, path: "m/44'/637'/0'/0'/0'")
        let account1 = try Ed25519Account.fromMnemonic(Self.standardMnemonic, path: "m/44'/637'/0'/0'/1'")
        let account2 = try Ed25519Account.fromMnemonic(Self.standardMnemonic, path: "m/44'/637'/0'/0'/2'")

        #expect(account0.accountAddress != account1.accountAddress)
        #expect(account1.accountAddress != account2.accountAddress)
        #expect(account0.accountAddress != account2.accountAddress)
    }

    // MARK: - Passphrase Changes Derivation

    @Test("Passphrase changes the derived keys")
    func passphraseChanges() throws {
        let accountNoPass = try Ed25519Account.fromMnemonic(Self.standardMnemonic, passphrase: "")
        let accountWithPass = try Ed25519Account.fromMnemonic(Self.standardMnemonic, passphrase: "TREZOR")
        #expect(accountNoPass.accountAddress != accountWithPass.accountAddress)
    }

    // MARK: - 24-word Mnemonic

    @Test("24-word mnemonic produces different address than 12-word")
    func twentyFourWordMnemonic() throws {
        // swiftlint:disable:next line_length
        let mnemonic24 = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon art"
        let account12 = try Ed25519Account.fromMnemonic(Self.standardMnemonic)
        let account24 = try Ed25519Account.fromMnemonic(mnemonic24)
        #expect(account12.accountAddress != account24.accountAddress)
    }

    // MARK: - Mnemonic Validation

    @Test("Standard mnemonic validates")
    func standardValidates() {
        #expect(Mnemonic.validate(Self.standardMnemonic))
    }

    @Test("24-word mnemonic validates")
    func twentyFourWordValidates() {
        // swiftlint:disable:next line_length
        let mnemonic24 = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon art"
        #expect(Mnemonic.validate(mnemonic24))
    }

    // MARK: - Invalid Mnemonics

    @Test("11 words is invalid")
    func elevenWords() {
        let mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon"
        #expect(!Mnemonic.validate(mnemonic))
    }

    @Test("13 words is invalid")
    func thirteenWords() {
        let mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about about"
        #expect(!Mnemonic.validate(mnemonic))
    }

    @Test("Invalid word is invalid")
    func invalidWord() {
        let mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon xyz"
        #expect(!Mnemonic.validate(mnemonic))
    }

    @Test("Wrong checksum is invalid")
    func wrongChecksum() {
        let mnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon"
        #expect(!Mnemonic.validate(mnemonic))
    }

    @Test("Mixed language is invalid")
    func mixedLanguage() {
        let mnemonic = "abandon 放弃 abandon abandon abandon abandon abandon abandon abandon abandon abandon about"
        #expect(!Mnemonic.validate(mnemonic))
    }

    // MARK: - Mnemonic Generation

    @Test("Generated 12-word mnemonic validates")
    func generate12() {
        let mnemonic = Mnemonic.generate(wordCount: .twelve)
        let words = mnemonic.split(separator: " ")
        #expect(words.count == 12)
        #expect(Mnemonic.validate(mnemonic))
    }

    @Test("Generated 24-word mnemonic validates")
    func generate24() {
        let mnemonic = Mnemonic.generate(wordCount: .twentyFour)
        let words = mnemonic.split(separator: " ")
        #expect(words.count == 24)
        #expect(Mnemonic.validate(mnemonic))
    }

    // MARK: - Valid Word Counts

    @Test("All valid word counts", arguments: [
        Mnemonic.WordCount.twelve,
        Mnemonic.WordCount.fifteen,
        Mnemonic.WordCount.eighteen,
        Mnemonic.WordCount.twentyOne,
        Mnemonic.WordCount.twentyFour,
    ])
    func validWordCounts(wordCount: Mnemonic.WordCount) {
        let mnemonic = Mnemonic.generate(wordCount: wordCount)
        let words = mnemonic.split(separator: " ")
        #expect(words.count == wordCount.rawValue)
        #expect(Mnemonic.validate(mnemonic))
    }

    // MARK: - Derivation Path Constants

    @Test("Default Aptos derivation path")
    func defaultPath() {
        #expect(DerivationPath.defaultAptos == "m/44'/637'/0'/0'/0'")
    }
}
