import CommonCrypto
import CryptoKit
import Foundation

/// BIP-39 mnemonic phrase generation, validation, and seed derivation.
public enum Mnemonic {
    /// Supported word counts for mnemonic generation.
    public enum WordCount: Int, Sendable {
        case twelve = 12
        case fifteen = 15
        case eighteen = 18
        case twentyOne = 21
        case twentyFour = 24

        /// Entropy bits for this word count.
        var entropyBits: Int {
            rawValue / 3 * 32
        }

        /// Entropy bytes for this word count.
        var entropyBytes: Int {
            entropyBits / 8
        }

        /// Checksum bits for this word count.
        var checksumBits: Int {
            entropyBits / 32
        }
    }

    /// Generates a random BIP-39 mnemonic phrase.
    public static func generate(wordCount: WordCount = .twelve) -> String {
        let entropy = generateEntropy(byteCount: wordCount.entropyBytes)
        return entropyToMnemonic(entropy)
    }

    /// Validates a BIP-39 mnemonic phrase (word list + checksum).
    public static func validate(_ phrase: String) -> Bool {
        let words = phrase.lowercased().split(separator: " ").map(String.init)

        // Check word count
        guard [12, 15, 18, 21, 24].contains(words.count) else { return false }

        // Check all words are in the wordlist
        let wordSet = Set(BIP39Wordlist.words)
        guard words.allSatisfy({ wordSet.contains($0) }) else { return false }

        // Reconstruct entropy and verify checksum
        guard let entropy = mnemonicToEntropy(words) else { return false }

        // Verify by re-encoding and comparing
        let regenerated = entropyToMnemonic(entropy)
        return regenerated == words.joined(separator: " ")
    }

    /// Derives a 64-byte seed from a mnemonic phrase using PBKDF2-HMAC-SHA512.
    ///
    /// - Parameters:
    ///   - phrase: The mnemonic phrase (space-separated words).
    ///   - passphrase: Optional passphrase (default: empty string).
    /// - Returns: 64-byte seed.
    public static func toSeed(_ phrase: String, passphrase: String = "") throws -> Data {
        guard validate(phrase) else {
            throw AptosError.parse(.invalidMnemonic("Invalid mnemonic phrase"))
        }

        let password = phrase.decomposedStringWithCompatibilityMapping
        let salt = ("mnemonic" + passphrase).decomposedStringWithCompatibilityMapping

        return try pbkdf2HMACSHA512(
            password: password,
            salt: salt,
            iterations: 2048,
            keyLength: 64
        )
    }

    // MARK: - Internal

    private static func generateEntropy(byteCount: Int) -> Data {
        var entropy = Data(count: byteCount)
        entropy.withUnsafeMutableBytes { buffer in
            _ = SecRandomCopyBytes(kSecRandomDefault, byteCount, buffer.baseAddress!)
        }
        return entropy
    }

    static func entropyToMnemonic(_ entropy: Data) -> String {
        let hash = AptosHashing.sha2_256(entropy)
        let checksumBits = entropy.count / 4 // 1 bit per 32 bits of entropy

        // Combine entropy bits + checksum bits
        var bits: [Bool] = []
        for byte in entropy {
            for i in (0 ..< 8).reversed() {
                bits.append((byte >> i) & 1 == 1)
            }
        }
        for i in 0 ..< checksumBits {
            let byte = hash[i / 8]
            bits.append((byte >> (7 - (i % 8))) & 1 == 1)
        }

        // Split into 11-bit groups and map to words
        var words: [String] = []
        for i in stride(from: 0, to: bits.count, by: 11) {
            var index = 0
            for j in 0 ..< 11 {
                if bits[i + j] {
                    index |= 1 << (10 - j)
                }
            }
            words.append(BIP39Wordlist.words[index])
        }

        return words.joined(separator: " ")
    }

    private static func mnemonicToEntropy(_ words: [String]) -> Data? {
        let wordMap: [String: Int] = {
            var map = [String: Int]()
            for (i, w) in BIP39Wordlist.words.enumerated() {
                map[w] = i
            }
            return map
        }()

        // Convert words to 11-bit indices
        var bits: [Bool] = []
        for word in words {
            guard let index = wordMap[word] else { return nil }
            for i in (0 ..< 11).reversed() {
                bits.append((index >> i) & 1 == 1)
            }
        }

        let checksumBits = words.count / 3
        let entropyBits = bits.count - checksumBits

        // Extract entropy bytes
        var entropy = Data()
        for i in stride(from: 0, to: entropyBits, by: 8) {
            var byte: UInt8 = 0
            for j in 0 ..< 8 {
                if bits[i + j] {
                    byte |= 1 << (7 - j)
                }
            }
            entropy.append(byte)
        }

        return entropy
    }

    private static func pbkdf2HMACSHA512(
        password: String,
        salt: String,
        iterations: UInt32,
        keyLength: Int
    ) throws -> Data {
        guard let passwordData = password.data(using: .utf8),
              let saltData = salt.data(using: .utf8)
        else {
            throw AptosError.crypto(.invalidSeed("Failed to encode password/salt as UTF-8"))
        }

        var derivedKey = Data(count: keyLength)
        let status = derivedKey.withUnsafeMutableBytes { derivedKeyBuffer in
            passwordData.withUnsafeBytes { passwordBuffer in
                saltData.withUnsafeBytes { saltBuffer in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBuffer.baseAddress?.assumingMemoryBound(to: Int8.self),
                        passwordData.count,
                        saltBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        saltData.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA512),
                        iterations,
                        derivedKeyBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        keyLength
                    )
                }
            }
        }

        guard status == kCCSuccess else {
            throw AptosError.crypto(.invalidSeed("PBKDF2 derivation failed with status: \(status)"))
        }

        return derivedKey
    }
}
