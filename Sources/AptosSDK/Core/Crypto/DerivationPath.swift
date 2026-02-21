import Foundation

/// BIP-44 derivation path parsing and constants.
public struct DerivationPath: Sendable, Equatable {
    /// The parsed path components (each is a child index; hardened indices have 0x80000000 set).
    public let components: [UInt32]

    /// Default Aptos Ed25519 derivation path: m/44'/637'/0'/0'/0'
    public static let defaultAptos = "m/44'/637'/0'/0'/0'"

    /// Default Aptos Secp256k1 derivation path: m/44'/637'/0'/0/0
    public static let defaultAptosSecp256k1 = "m/44'/637'/0'/0/0"

    /// The hardened offset.
    public static let hardenedOffset: UInt32 = 0x8000_0000

    /// Parses a derivation path string like "m/44'/637'/0'/0'/0'".
    public init(_ path: String) throws {
        guard path.hasPrefix("m/") else {
            throw AptosError.parse(.invalidDerivationPath(
                "Path must start with 'm/': \(path)"
            ))
        }

        let segments = path.dropFirst(2).split(separator: "/")
        guard !segments.isEmpty else {
            throw AptosError.parse(.invalidDerivationPath(
                "Path must have at least one component: \(path)"
            ))
        }

        var parsed: [UInt32] = []
        for segment in segments {
            let isHardened = segment.hasSuffix("'")
            let indexStr = isHardened ? String(segment.dropLast()) : String(segment)

            guard let index = UInt32(indexStr) else {
                throw AptosError.parse(.invalidDerivationPath(
                    "Invalid path component: \(segment)"
                ))
            }

            guard index < Self.hardenedOffset else {
                throw AptosError.parse(.invalidDerivationPath(
                    "Index too large: \(index)"
                ))
            }

            parsed.append(isHardened ? index | Self.hardenedOffset : index)
        }

        components = parsed
    }

    /// Whether all components are hardened (required for Ed25519 SLIP-0010).
    public var isFullyHardened: Bool {
        components.allSatisfy { $0 & Self.hardenedOffset != 0 }
    }
}
