import Foundation

// MARK: - AnySignatureVariant

/// Variant identifiers for AnySignature.
public enum AnySignatureVariant: UInt32, Sendable {
    case ed25519 = 0
    case secp256k1 = 1
    case webAuthn = 2
    case keyless = 3
}

// MARK: - AnySignature

/// A signature that can be any of the supported signature types.
public enum AnySignature: Sendable, Equatable {
    case ed25519(Ed25519Signature)
    case secp256k1(Secp256k1Signature)
    case webAuthn(WebAuthnSignature)
    case keyless(KeylessSignature)

    /// The variant identifier.
    public var variant: AnySignatureVariant {
        switch self {
        case .ed25519: .ed25519
        case .secp256k1: .secp256k1
        case .webAuthn: .webAuthn
        case .keyless: .keyless
        }
    }
}

// MARK: BCSSerializable, BCSDeserializable

extension AnySignature: BCSSerializable, BCSDeserializable {
    public func serialize(to serializer: inout Serializer) throws {
        try serializer.serializeU32AsUleb128(variant.rawValue)
        switch self {
        case let .ed25519(sig):
            try sig.serialize(to: &serializer)
        case let .secp256k1(sig):
            try sig.serialize(to: &serializer)
        case let .webAuthn(sig):
            try sig.serialize(to: &serializer)
        case let .keyless(sig):
            try sig.serialize(to: &serializer)
        }
    }

    public static func deserialize(from deserializer: inout Deserializer) throws -> AnySignature {
        let variant = try deserializer.deserializeUleb128()
        switch variant {
        case 0: return .ed25519(try Ed25519Signature.deserialize(from: &deserializer))
        case 1: return .secp256k1(try Secp256k1Signature.deserialize(from: &deserializer))
        case 2: return .webAuthn(try WebAuthnSignature.deserialize(from: &deserializer))
        case 3: return .keyless(try KeylessSignature.deserialize(from: &deserializer))
        default:
            throw AptosError.serialization(.invalidData("Unknown AnySignature variant: \(variant)"))
        }
    }
}

// MARK: - WebAuthnSignature

/// WebAuthn (Secp256r1) signature with authenticator data.
public struct WebAuthnSignature: Sendable, Equatable {
    public let signature: Secp256r1Signature
    public let authenticatorData: Data
    public let clientDataJSON: Data

    public init(signature: Secp256r1Signature, authenticatorData: Data, clientDataJSON: Data) {
        self.signature = signature
        self.authenticatorData = authenticatorData
        self.clientDataJSON = clientDataJSON
    }
}

// MARK: BCSSerializable, BCSDeserializable

extension WebAuthnSignature: BCSSerializable, BCSDeserializable {
    public func serialize(to serializer: inout Serializer) throws {
        try signature.serialize(to: &serializer)
        try serializer.serializeBytes(authenticatorData)
        try serializer.serializeBytes(clientDataJSON)
    }

    public static func deserialize(from deserializer: inout Deserializer) throws -> WebAuthnSignature {
        let sig = try Secp256r1Signature.deserialize(from: &deserializer)
        let authData = try deserializer.deserializeBytes()
        let clientData = try deserializer.deserializeBytes()
        return WebAuthnSignature(signature: sig, authenticatorData: authData, clientDataJSON: clientData)
    }
}

// MARK: - KeylessSignature

/// Keyless signature placeholder (for future keyless auth support).
public struct KeylessSignature: Sendable, Equatable {
    public let data: Data

    public init(data: Data) {
        self.data = data
    }
}

// MARK: BCSSerializable, BCSDeserializable

extension KeylessSignature: BCSSerializable, BCSDeserializable {
    public func serialize(to serializer: inout Serializer) throws {
        try serializer.serializeBytes(data)
    }

    public static func deserialize(from deserializer: inout Deserializer) throws -> KeylessSignature {
        let bytes = try deserializer.deserializeBytes()
        return KeylessSignature(data: bytes)
    }
}
