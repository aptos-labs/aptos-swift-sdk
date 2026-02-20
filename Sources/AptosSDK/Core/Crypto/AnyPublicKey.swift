import Foundation

/// Variant index for `AnyPublicKey` BCS serialization.
public enum AnyPublicKeyVariant: UInt32, Sendable {
    case ed25519 = 0
    case secp256k1 = 1
    case secp256r1 = 2
    case keyless = 3
    case federatedKeyless = 4
}

/// Wraps any public key variant for the SingleKey/MultiKey authentication scheme.
///
/// This enum corresponds to the on-chain `AnyPublicKey` type where each variant
/// is identified by a ULEB128-encoded variant index.
public enum AnyPublicKey: Sendable, Hashable {
    case ed25519(Ed25519PublicKey)
    case secp256k1(Secp256k1PublicKey)
    case secp256r1(Secp256r1PublicKey)
    case keyless(KeylessPublicKey)
    case federatedKeyless(FederatedKeylessPublicKey)

    /// The variant index used in BCS serialization.
    public var variantIndex: UInt32 {
        switch self {
        case .ed25519: return AnyPublicKeyVariant.ed25519.rawValue
        case .secp256k1: return AnyPublicKeyVariant.secp256k1.rawValue
        case .secp256r1: return AnyPublicKeyVariant.secp256r1.rawValue
        case .keyless: return AnyPublicKeyVariant.keyless.rawValue
        case .federatedKeyless: return AnyPublicKeyVariant.federatedKeyless.rawValue
        }
    }

    /// The raw key bytes (delegates to the underlying key).
    public var data: Data {
        switch self {
        case .ed25519(let key): return key.data
        case .secp256k1(let key): return key.data
        case .secp256r1(let key): return key.data
        case .keyless(let key): return key.data
        case .federatedKeyless(let key): return key.data
        }
    }

}

// MARK: - Serializable / Deserializable

extension AnyPublicKey: Serializable {
    public func serialize(to serializer: inout Serializer) {
        serializer.serializeU32AsUleb128(variantIndex)
        switch self {
        case .ed25519(let key): key.serialize(to: &serializer)
        case .secp256k1(let key): key.serialize(to: &serializer)
        case .secp256r1(let key): key.serialize(to: &serializer)
        case .keyless(let key): key.serialize(to: &serializer)
        case .federatedKeyless(let key): key.serialize(to: &serializer)
        }
    }
}

extension AnyPublicKey: Deserializable {
    public static func deserialize(from deserializer: inout Deserializer) throws -> AnyPublicKey {
        let variant = try deserializer.deserializeUleb128()
        switch variant {
        case AnyPublicKeyVariant.ed25519.rawValue:
            return .ed25519(try Ed25519PublicKey.deserialize(from: &deserializer))
        case AnyPublicKeyVariant.secp256k1.rawValue:
            return .secp256k1(try Secp256k1PublicKey.deserialize(from: &deserializer))
        case AnyPublicKeyVariant.secp256r1.rawValue:
            return .secp256r1(try Secp256r1PublicKey.deserialize(from: &deserializer))
        case AnyPublicKeyVariant.keyless.rawValue:
            return .keyless(try KeylessPublicKey.deserialize(from: &deserializer))
        case AnyPublicKeyVariant.federatedKeyless.rawValue:
            return .federatedKeyless(try FederatedKeylessPublicKey.deserialize(from: &deserializer))
        default:
            throw AptosError.deserializationError("Unknown AnyPublicKey variant: \(variant)")
        }
    }
}
