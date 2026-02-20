import Foundation

/// Variant index for `AnySignature` BCS serialization.
public enum AnySignatureVariant: UInt32, Sendable {
    case ed25519 = 0
    case secp256k1 = 1
    case webAuthn = 2
    case keyless = 3
}

/// Wraps any signature variant for the SingleKey authentication scheme.
public enum AnySignature: AccountSignature {
    case ed25519(Ed25519Signature)
    case secp256k1(Secp256k1Signature)
    case webAuthn(Data)
    case keyless(KeylessSignature)

    public var variantIndex: UInt32 {
        switch self {
        case .ed25519: return AnySignatureVariant.ed25519.rawValue
        case .secp256k1: return AnySignatureVariant.secp256k1.rawValue
        case .webAuthn: return AnySignatureVariant.webAuthn.rawValue
        case .keyless: return AnySignatureVariant.keyless.rawValue
        }
    }

    public var data: Data {
        switch self {
        case .ed25519(let sig): return sig.data
        case .secp256k1(let sig): return sig.data
        case .webAuthn(let bytes): return bytes
        case .keyless(let sig): return sig.data
        }
    }
}

// MARK: - Serializable / Deserializable

extension AnySignature: Serializable {
    public func serialize(to serializer: inout Serializer) {
        serializer.serializeU32AsUleb128(variantIndex)
        switch self {
        case .ed25519(let sig): sig.serialize(to: &serializer)
        case .secp256k1(let sig): sig.serialize(to: &serializer)
        case .webAuthn(let bytes): serializer.serializeBytes(bytes)
        case .keyless(let sig): sig.serialize(to: &serializer)
        }
    }
}

extension AnySignature: Deserializable {
    public static func deserialize(from deserializer: inout Deserializer) throws -> AnySignature {
        let variant = try deserializer.deserializeUleb128()
        switch variant {
        case AnySignatureVariant.ed25519.rawValue:
            return .ed25519(try Ed25519Signature.deserialize(from: &deserializer))
        case AnySignatureVariant.secp256k1.rawValue:
            return .secp256k1(try Secp256k1Signature.deserialize(from: &deserializer))
        case AnySignatureVariant.webAuthn.rawValue:
            return .webAuthn(try deserializer.deserializeBytes())
        case AnySignatureVariant.keyless.rawValue:
            return .keyless(try KeylessSignature.deserialize(from: &deserializer))
        default:
            throw AptosError.deserializationError("Unknown AnySignature variant: \(variant)")
        }
    }
}
