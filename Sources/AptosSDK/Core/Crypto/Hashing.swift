import Foundation
import CryptoKit

/// Hashing utilities for the Aptos SDK.
public enum AptosHashing {
    /// SHA2-256 hash using CryptoKit.
    public static func sha2_256(_ data: Data) -> Data {
        Data(CryptoKit.SHA256.hash(data: data))
    }

    /// SHA3-256 hash.
    public static func sha3_256(_ data: Data) -> Data {
        SHA3.sha256(data)
    }

    /// SHA3-256 hash of raw bytes.
    public static func sha3_256(_ bytes: [UInt8]) -> Data {
        SHA3.sha256(bytes)
    }

    /// Domain-separated SHA3-256 hash.
    ///
    /// Computes `SHA3-256(SHA3-256(domain) || data)`.
    /// Used for signing messages, authentication keys, etc.
    public static func hashWithDomainSeparation(domain: String, data: Data) -> Data {
        SHA3.hashWithDomain(domain, data)
    }

    /// Computes the signing message prefix for a given domain string.
    ///
    /// Returns `SHA3-256(domain_bytes)`.
    public static func signingPrefix(_ domain: String) -> Data {
        SHA3.signingPrefix(domain)
    }

    /// HMAC-SHA512 using CryptoKit.
    public static func hmacSHA512(key: some ContiguousBytes, data: some DataProtocol) -> Data {
        let auth = HMAC<SHA512>.authenticationCode(for: data, using: SymmetricKey(data: key))
        return Data(auth)
    }
}

/// Standard domain strings used in the Aptos protocol.
public enum AptosDomain {
    public static let rawTransaction = "APTOS::RawTransaction"
    public static let rawTransactionWithData = "APTOS::RawTransactionWithData"
    public static let accountAbstractionSigningData = "APTOS::AASigningData"
}
