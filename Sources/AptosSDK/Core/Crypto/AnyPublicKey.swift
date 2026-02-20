import Foundation

/// Variant identifiers for AnyPublicKey.
public enum AnyPublicKeyVariant: UInt32, Sendable {
    case ed25519 = 0
    case secp256k1 = 1
    case secp256r1 = 2
    case keyless = 3
    case federatedKeyless = 4
}

/// A public key that can be any of the supported key types.
///
/// Used with the SingleKey authentication scheme.
public enum AnyPublicKey: Sendable, Equatable {
    case ed25519(Ed25519PublicKey)
    case secp256k1(Secp256k1PublicKey)
    case secp256r1(Secp256r1PublicKey)
    case keyless(KeylessPublicKey)

    /// The variant identifier for this key type.
    public var variant: AnyPublicKeyVariant {
        switch self {
        case .ed25519: return .ed25519
        case .secp256k1: return .secp256k1
        case .secp256r1: return .secp256r1
        case .keyless: return .keyless
        }
    }

    /// The raw public key data.
    public var publicKeyData: Data {
        switch self {
        case .ed25519(let k): return k.data
        case .secp256k1(let k): return k.data
        case .secp256r1(let k): return k.data
        case .keyless(let k): return k.data
        }
    }
}

extension AnyPublicKey: BCSSerializable, BCSDeserializable {
    public func serialize(to serializer: inout Serializer) throws {
        try serializer.serializeU32AsUleb128(variant.rawValue)
        switch self {
        case .ed25519(let key):
            try key.serialize(to: &serializer)
        case .secp256k1(let key):
            try key.serialize(to: &serializer)
        case .secp256r1(let key):
            try key.serialize(to: &serializer)
        case .keyless(let key):
            try key.serialize(to: &serializer)
        }
    }

    public static func deserialize(from deserializer: inout Deserializer) throws -> AnyPublicKey {
        let variant = try deserializer.deserializeUleb128()
        switch variant {
        case 0: return .ed25519(try Ed25519PublicKey.deserialize(from: &deserializer))
        case 1: return .secp256k1(try Secp256k1PublicKey.deserialize(from: &deserializer))
        case 2: return .secp256r1(try Secp256r1PublicKey.deserialize(from: &deserializer))
        case 3: return .keyless(try KeylessPublicKey.deserialize(from: &deserializer))
        default:
            throw AptosError.serialization(.invalidData("Unknown AnyPublicKey variant: \(variant)"))
        }
    }
}
