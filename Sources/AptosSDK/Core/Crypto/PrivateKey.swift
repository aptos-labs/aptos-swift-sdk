import Foundation

/// Utility for AIP-80 private key format handling.
public enum PrivateKeyUtils {
    /// Supported private key type prefixes.
    public enum PrivateKeyVariant: String, Sendable {
        case ed25519 = "ed25519-priv-"
        case secp256k1 = "secp256k1-priv-"
        case secp256r1 = "secp256r1-priv-"
    }

    /// Formats a private key hex string in AIP-80 format.
    public static func formatPrivateKey(hex: String, type: PrivateKeyVariant) -> String {
        let stripped = Hex.stripPrefix(hex)
        return "\(type.rawValue)\(stripped)"
    }

    /// Parses an AIP-80 formatted private key string and returns the variant and hex bytes.
    public static func parseAIP80(_ aip80: String) throws -> (variant: PrivateKeyVariant, data: Data) {
        for variant in [PrivateKeyVariant.ed25519, .secp256k1, .secp256r1] {
            if aip80.hasPrefix(variant.rawValue) {
                let hex = String(aip80.dropFirst(variant.rawValue.count))
                let data = try Hex.decode(hex)
                return (variant, data)
            }
        }
        throw AptosError.crypto(.invalidPrivateKey(
            "Invalid AIP-80 format. Expected prefix: ed25519-priv-, secp256k1-priv-, or secp256r1-priv-"))
    }

    /// Returns true if the string is a valid AIP-80 private key format.
    public static func isAIP80(_ str: String) -> Bool {
        for variant in [PrivateKeyVariant.ed25519, .secp256k1, .secp256r1] {
            if str.hasPrefix(variant.rawValue) { return true }
        }
        return false
    }
}
