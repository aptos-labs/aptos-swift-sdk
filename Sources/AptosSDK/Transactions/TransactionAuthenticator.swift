import Foundation

// MARK: - AccountAuthenticator

/// Per-account authenticator containing a signature from a single account.
public enum AccountAuthenticator: Sendable, Equatable {
    /// Legacy Ed25519 authenticator (variant 0).
    case ed25519(publicKey: Ed25519PublicKey, signature: Ed25519Signature)
    /// Legacy multi-Ed25519 authenticator (variant 1).
    case multiEd25519(publicKey: MultiEd25519PublicKey, signature: MultiEd25519Signature)
    /// Single key authenticator (variant 2).
    case singleKey(publicKey: AnyPublicKey, signature: AnySignature)
    /// Multi-key authenticator (variant 3).
    case multiKey(publicKey: MultiKey, signature: MultiKeySignature)
    /// No authenticator placeholder for simulation (variant 4).
    case noAccountAuthenticator
    /// Account abstraction authenticator (variant 5).
    case abstraction(functionInfo: String, authData: Data)

    private var variantIndex: UInt32 {
        switch self {
        case .ed25519: 0
        case .multiEd25519: 1
        case .singleKey: 2
        case .multiKey: 3
        case .noAccountAuthenticator: 4
        case .abstraction: 5
        }
    }
}

// MARK: BCSSerializable, BCSDeserializable

extension AccountAuthenticator: BCSSerializable, BCSDeserializable {
    public func serialize(to serializer: inout Serializer) throws {
        try serializer.serializeU32AsUleb128(variantIndex)
        switch self {
        case let .ed25519(pubKey, sig):
            try pubKey.serialize(to: &serializer)
            try sig.serialize(to: &serializer)
        case let .multiEd25519(pubKey, sig):
            try pubKey.serialize(to: &serializer)
            try sig.serialize(to: &serializer)
        case let .singleKey(pubKey, sig):
            try pubKey.serialize(to: &serializer)
            try sig.serialize(to: &serializer)
        case let .multiKey(pubKey, sig):
            try pubKey.serialize(to: &serializer)
            try sig.serialize(to: &serializer)
        case .noAccountAuthenticator:
            break
        case let .abstraction(funcInfo, authData):
            try serializer.serializeStr(funcInfo)
            try serializer.serializeBytes(authData)
        }
    }

    public static func deserialize(from deserializer: inout Deserializer) throws -> AccountAuthenticator {
        let variant = try deserializer.deserializeUleb128()
        switch variant {
        case 0:
            let pubKey = try Ed25519PublicKey.deserialize(from: &deserializer)
            let sig = try Ed25519Signature.deserialize(from: &deserializer)
            return .ed25519(publicKey: pubKey, signature: sig)
        case 1:
            let pubKey = try MultiEd25519PublicKey.deserialize(from: &deserializer)
            let sig = try MultiEd25519Signature.deserialize(from: &deserializer)
            return .multiEd25519(publicKey: pubKey, signature: sig)
        case 2:
            let pubKey = try AnyPublicKey.deserialize(from: &deserializer)
            let sig = try AnySignature.deserialize(from: &deserializer)
            return .singleKey(publicKey: pubKey, signature: sig)
        case 3:
            let pubKey = try MultiKey.deserialize(from: &deserializer)
            let sig = try MultiKeySignature.deserialize(from: &deserializer)
            return .multiKey(publicKey: pubKey, signature: sig)
        case 4:
            return .noAccountAuthenticator
        case 5:
            let funcInfo = try deserializer.deserializeStr()
            let authData = try deserializer.deserializeBytes()
            return .abstraction(functionInfo: funcInfo, authData: authData)
        default:
            throw AptosError.serialization(.invalidData(
                "Unknown AccountAuthenticator variant: \(variant)"
            ))
        }
    }
}

// MARK: - TransactionAuthenticator

/// Top-level authenticator wrapping all signatures for a transaction.
public enum TransactionAuthenticator: Sendable, Equatable {
    /// Legacy single Ed25519 signer (variant 0).
    case ed25519(publicKey: Ed25519PublicKey, signature: Ed25519Signature)
    /// Legacy multi-Ed25519 signer (variant 1).
    case multiEd25519(publicKey: MultiEd25519PublicKey, signature: MultiEd25519Signature)
    /// Multi-agent transaction (variant 2).
    case multiAgent(
        sender: AccountAuthenticator,
        secondarySignerAddresses: [AccountAddress],
        secondarySigners: [AccountAuthenticator]
    )
    /// Fee payer transaction (variant 3).
    case feePayer(
        sender: AccountAuthenticator,
        secondarySignerAddresses: [AccountAddress],
        secondarySigners: [AccountAuthenticator],
        feePayerAddress: AccountAddress,
        feePayerAuthenticator: AccountAuthenticator
    )
    /// Single sender with any key type (variant 4).
    case singleSender(AccountAuthenticator)

    private var variantIndex: UInt32 {
        switch self {
        case .ed25519: 0
        case .multiEd25519: 1
        case .multiAgent: 2
        case .feePayer: 3
        case .singleSender: 4
        }
    }
}

// MARK: BCSSerializable, BCSDeserializable

extension TransactionAuthenticator: BCSSerializable, BCSDeserializable {
    public func serialize(to serializer: inout Serializer) throws {
        try serializer.serializeU32AsUleb128(variantIndex)
        switch self {
        case let .ed25519(pubKey, sig):
            try pubKey.serialize(to: &serializer)
            try sig.serialize(to: &serializer)
        case let .multiEd25519(pubKey, sig):
            try pubKey.serialize(to: &serializer)
            try sig.serialize(to: &serializer)
        case let .multiAgent(sender, addrs, signers):
            try sender.serialize(to: &serializer)
            try serializer.serializeVector(addrs)
            try serializer.serializeVector(signers)
        case let .feePayer(sender, addrs, signers, feeAddr, feeAuth):
            try sender.serialize(to: &serializer)
            try serializer.serializeVector(addrs)
            try serializer.serializeVector(signers)
            try feeAddr.serialize(to: &serializer)
            try feeAuth.serialize(to: &serializer)
        case let .singleSender(auth):
            try auth.serialize(to: &serializer)
        }
    }

    public static func deserialize(from deserializer: inout Deserializer) throws -> TransactionAuthenticator {
        let variant = try deserializer.deserializeUleb128()
        switch variant {
        case 0:
            let pub = try Ed25519PublicKey.deserialize(from: &deserializer)
            let sig = try Ed25519Signature.deserialize(from: &deserializer)
            return .ed25519(publicKey: pub, signature: sig)
        case 1:
            let pub = try MultiEd25519PublicKey.deserialize(from: &deserializer)
            let sig = try MultiEd25519Signature.deserialize(from: &deserializer)
            return .multiEd25519(publicKey: pub, signature: sig)
        case 2:
            let sender = try AccountAuthenticator.deserialize(from: &deserializer)
            let addrs = try deserializer.deserializeVector(AccountAddress.self)
            let signers = try deserializer.deserializeVector(AccountAuthenticator.self)
            return .multiAgent(sender: sender, secondarySignerAddresses: addrs, secondarySigners: signers)
        case 3:
            let sender = try AccountAuthenticator.deserialize(from: &deserializer)
            let addrs = try deserializer.deserializeVector(AccountAddress.self)
            let signers = try deserializer.deserializeVector(AccountAuthenticator.self)
            let feeAddr = try AccountAddress.deserialize(from: &deserializer)
            let feeAuth = try AccountAuthenticator.deserialize(from: &deserializer)
            return .feePayer(
                sender: sender,
                secondarySignerAddresses: addrs,
                secondarySigners: signers,
                feePayerAddress: feeAddr,
                feePayerAuthenticator: feeAuth
            )
        case 4:
            let auth = try AccountAuthenticator.deserialize(from: &deserializer)
            return .singleSender(auth)
        default:
            throw AptosError.serialization(.invalidData(
                "Unknown TransactionAuthenticator variant: \(variant)"
            ))
        }
    }
}
