import CryptoKit
import Foundation

// MARK: - SLIP0010

/// SLIP-0010 Ed25519 hierarchical deterministic key derivation.
public enum SLIP0010 {
    /// Derives a private key from a seed using the given derivation path.
    ///
    /// Ed25519 SLIP-0010 only supports hardened derivation.
    public static func derivePath(_ path: String, seed: Data) throws -> (key: Data, chainCode: Data) {
        let derivationPath = try DerivationPath(path)
        guard derivationPath.isFullyHardened else {
            throw AptosError.crypto(.invalidSeed(
                "Ed25519 SLIP-0010 only supports hardened derivation"
            ))
        }
        // Master key derivation
        var (key, chainCode) = masterKey(seed: seed)

        // Derive each child
        for index in derivationPath.components {
            (key, chainCode) = try deriveChild(key: key, chainCode: chainCode, index: index)
        }

        return (key: key, chainCode: chainCode)
    }

    /// Computes the master key from a seed.
    ///
    /// HMAC-SHA512(key: "ed25519 seed", data: seed)
    static func masterKey(seed: Data) -> (key: Data, chainCode: Data) {
        let hmac = AptosHashing.hmacSHA512(
            key: Data("ed25519 seed".utf8),
            data: seed
        )
        return (key: hmac.prefix(32), chainCode: hmac.suffix(32))
    }

    /// Derives a hardened child key.
    ///
    /// HMAC-SHA512(key: chainCode, data: 0x00 || key || index_bytes)
    static func deriveChild(key: Data, chainCode: Data, index: UInt32) throws -> (key: Data, chainCode: Data) {
        guard index & DerivationPath.hardenedOffset != 0 else {
            throw AptosError.crypto(.invalidSeed(
                "Ed25519 SLIP-0010 requires hardened derivation (index must have hardened bit set)"
            ))
        }

        var data = Data([0x00])
        data.append(key)
        var indexBytes = index.bigEndian
        data.append(Data(bytes: &indexBytes, count: 4))

        let hmac = AptosHashing.hmacSHA512(key: chainCode, data: data)
        return (key: hmac.prefix(32), chainCode: hmac.suffix(32))
    }
}

// MARK: - BIP32

/// BIP-32 hierarchical deterministic key derivation for Secp256k1.
public enum BIP32 {
    /// Derives a private key from a seed using the given derivation path.
    public static func derivePath(_ path: String, seed: Data) throws -> (key: Data, chainCode: Data) {
        let derivationPath = try DerivationPath(path)

        // Master key derivation
        var (key, chainCode) = masterKey(seed: seed)

        // Derive each child
        for index in derivationPath.components {
            (key, chainCode) = try deriveChild(key: key, chainCode: chainCode, index: index)
        }

        return (key: key, chainCode: chainCode)
    }

    /// Computes the master key from a seed.
    ///
    /// HMAC-SHA512(key: "Bitcoin seed", data: seed)
    static func masterKey(seed: Data) -> (key: Data, chainCode: Data) {
        let hmac = AptosHashing.hmacSHA512(
            key: Data("Bitcoin seed".utf8),
            data: seed
        )
        return (key: hmac.prefix(32), chainCode: hmac.suffix(32))
    }

    /// Derives a child key (hardened or normal).
    static func deriveChild(key: Data, chainCode: Data, index: UInt32) throws -> (key: Data, chainCode: Data) {
        var data = Data()

        if index & DerivationPath.hardenedOffset != 0 {
            // Hardened: 0x00 || key || index
            data.append(0x00)
            data.append(key)
        } else {
            // Normal: compressed_pubkey || index
            let pubKey = try Secp256k1PrivateKey(data: key).publicKey()
            data.append(pubKey.data)
        }

        var indexBytes = index.bigEndian
        data.append(Data(bytes: &indexBytes, count: 4))

        let hmac = AptosHashing.hmacSHA512(key: chainCode, data: data)
        let childKey = hmac.prefix(32)
        let childChainCode = hmac.suffix(32)

        return (key: Data(childKey), chainCode: Data(childChainCode))
    }
}
