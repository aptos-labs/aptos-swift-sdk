import Foundation

/// Private key type variants for AIP-80 formatting.
public enum PrivateKeyVariant: String, Sendable {
    case ed25519
    case secp256k1
    case secp256r1
}

/// AIP-80 private key formatting utilities.
public enum PrivateKeyFormat {
    /// Format a private key hex string in AIP-80 format.
    ///
    /// - Parameters:
    ///   - hex: The raw private key bytes as a hex string.
    ///   - type: The key algorithm type.
    /// - Returns: A string in the format `{type}-priv-{hex}`.
    public static func format(_ hex: String, type: PrivateKeyVariant) -> String {
        "\(type.rawValue)-priv-\(hex)"
    }

    /// Parse an AIP-80 formatted private key string.
    ///
    /// - Parameter aip80String: A string like `ed25519-priv-0x...`.
    /// - Returns: A tuple of the key type and raw hex bytes.
    /// - Throws: `AptosError.invalidArgument` if the format is invalid.
    public static func parse(_ aip80String: String) throws -> (type: PrivateKeyVariant, data: Data) {
        if aip80String.hasPrefix("ed25519-priv-") {
            let hex = String(aip80String.dropFirst("ed25519-priv-".count))
            return (.ed25519, try Hex.decode(hex))
        } else if aip80String.hasPrefix("secp256k1-priv-") {
            let hex = String(aip80String.dropFirst("secp256k1-priv-".count))
            return (.secp256k1, try Hex.decode(hex))
        } else if aip80String.hasPrefix("secp256r1-priv-") {
            let hex = String(aip80String.dropFirst("secp256r1-priv-".count))
            return (.secp256r1, try Hex.decode(hex))
        }
        throw AptosError.invalidArgument(
            "Unrecognized AIP-80 private key format: \(aip80String)"
        )
    }
}
