import Foundation

// MARK: - AnyPublicKeyVariant

/// Variant identifiers for AnyPublicKey.
public enum AnyPublicKeyVariant: UInt32, Sendable {
    case ed25519 = 0
    case secp256k1 = 1
    case secp256r1 = 2
    case keyless = 3
    case federatedKeyless = 4
}

// MARK: - AnyPublicKey

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
        case .ed25519: .ed25519
        case .secp256k1: .secp256k1
        case .secp256r1: .secp256r1
        case .keyless: .keyless
        }
    }

    /// The raw public key data.
    public var publicKeyData: Data {
        switch self {
        case let .ed25519(k): k.data
        case let .secp256k1(k): k.data
        case let .secp256r1(k): k.data
        case let .keyless(k): k.data
        }
    }
}

// MARK: BCSSerializable, BCSDeserializable

extension AnyPublicKey: BCSSerializable, BCSDeserializable {
    public func serialize(to serializer: inout Serializer) throws {
        try serializer.serializeU32AsUleb128(variant.rawValue)
        switch self {
        case let .ed25519(key):
            try key.serialize(to: &serializer)
        case let .secp256k1(key):
            try key.serialize(to: &serializer)
        case let .secp256r1(key):
            try key.serialize(to: &serializer)
        case let .keyless(key):
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
