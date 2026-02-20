import Foundation

/// Per-account authenticator variants.
public enum AccountAuthenticator: Serializable, Deserializable, Sendable, Hashable {
    case ed25519(publicKey: Ed25519PublicKey, signature: Ed25519Signature)              // 0
    case multiEd25519(publicKey: MultiEd25519PublicKey, signature: MultiEd25519Signature)  // 1
    case singleKey(publicKey: AnyPublicKey, signature: AnySignature)                   // 2
    case multiKey(publicKey: MultiKey, signatures: MultiKeySignature)                  // 3
    case noAccountAuthenticator                                                        // 4
    case abstraction(AccountAuthenticatorAbstraction)                                  // 5

    private enum Variant: UInt32 {
        case ed25519 = 0
        case multiEd25519 = 1
        case singleKey = 2
        case multiKey = 3
        case noAccountAuthenticator = 4
        case abstraction = 5
    }

    public func serialize(to serializer: inout Serializer) {
        switch self {
        case .ed25519(let pk, let sig):
            serializer.serializeU32AsUleb128(Variant.ed25519.rawValue)
            pk.serialize(to: &serializer)
            sig.serialize(to: &serializer)

        case .multiEd25519(let pk, let sig):
            serializer.serializeU32AsUleb128(Variant.multiEd25519.rawValue)
            pk.serialize(to: &serializer)
            sig.serialize(to: &serializer)

        case .singleKey(let pk, let sig):
            serializer.serializeU32AsUleb128(Variant.singleKey.rawValue)
            pk.serialize(to: &serializer)
            sig.serialize(to: &serializer)

        case .multiKey(let pk, let sigs):
            serializer.serializeU32AsUleb128(Variant.multiKey.rawValue)
            pk.serialize(to: &serializer)
            sigs.serialize(to: &serializer)

        case .noAccountAuthenticator:
            serializer.serializeU32AsUleb128(Variant.noAccountAuthenticator.rawValue)

        case .abstraction(let aa):
            serializer.serializeU32AsUleb128(Variant.abstraction.rawValue)
            aa.serialize(to: &serializer)
        }
    }

    public static func deserialize(from deserializer: inout Deserializer) throws -> AccountAuthenticator {
        let variant = try deserializer.deserializeUleb128()
        switch variant {
        case Variant.ed25519.rawValue:
            let pk = try Ed25519PublicKey.deserialize(from: &deserializer)
            let sig = try Ed25519Signature.deserialize(from: &deserializer)
            return .ed25519(publicKey: pk, signature: sig)

        case Variant.multiEd25519.rawValue:
            let pk = try MultiEd25519PublicKey.deserialize(from: &deserializer)
            let sig = try MultiEd25519Signature.deserialize(from: &deserializer)
            return .multiEd25519(publicKey: pk, signature: sig)

        case Variant.singleKey.rawValue:
            let pk = try AnyPublicKey.deserialize(from: &deserializer)
            let sig = try AnySignature.deserialize(from: &deserializer)
            return .singleKey(publicKey: pk, signature: sig)

        case Variant.multiKey.rawValue:
            let pk = try MultiKey.deserialize(from: &deserializer)
            let sigs = try MultiKeySignature.deserialize(from: &deserializer)
            return .multiKey(publicKey: pk, signatures: sigs)

        case Variant.noAccountAuthenticator.rawValue:
            return .noAccountAuthenticator

        case Variant.abstraction.rawValue:
            let aa = try AccountAuthenticatorAbstraction.deserialize(from: &deserializer)
            return .abstraction(aa)

        default:
            throw AptosError.deserializationError("Unknown AccountAuthenticator variant: \(variant)")
        }
    }
}

/// Account abstraction authenticator data.
public struct AccountAuthenticatorAbstraction: Serializable, Deserializable, Sendable, Hashable {
    public let moduleAddress: AccountAddress
    public let moduleName: String
    public let functionName: String
    public let signingMessageDigest: Data
    public let abstractionSignature: Data

    public init(
        moduleAddress: AccountAddress,
        moduleName: String,
        functionName: String,
        signingMessageDigest: Data,
        abstractionSignature: Data
    ) {
        self.moduleAddress = moduleAddress
        self.moduleName = moduleName
        self.functionName = functionName
        self.signingMessageDigest = signingMessageDigest
        self.abstractionSignature = abstractionSignature
    }

    public func serialize(to serializer: inout Serializer) {
        moduleAddress.serialize(to: &serializer)
        serializer.serializeStr(moduleName)
        serializer.serializeStr(functionName)
        serializer.serializeU32AsUleb128(0)  // V1 variant
        serializer.serializeBytes(signingMessageDigest)
        serializer.serializeFixedBytes(abstractionSignature)
    }

    public static func deserialize(
        from deserializer: inout Deserializer
    ) throws -> AccountAuthenticatorAbstraction {
        let addr = try AccountAddress.deserialize(from: &deserializer)
        let modName = try deserializer.deserializeStr()
        let funcName = try deserializer.deserializeStr()
        _ = try deserializer.deserializeUleb128()  // variant
        let digest = try deserializer.deserializeBytes()
        let sig = try deserializer.deserializeBytes()
        return AccountAuthenticatorAbstraction(
            moduleAddress: addr,
            moduleName: modName,
            functionName: funcName,
            signingMessageDigest: digest,
            abstractionSignature: sig
        )
    }
}

/// Transaction-level authenticator wrapping all signatures.
public enum TransactionAuthenticator: Serializable, Deserializable, Sendable, Hashable {
    case ed25519(publicKey: Ed25519PublicKey, signature: Ed25519Signature)               // 0
    case multiEd25519(publicKey: MultiEd25519PublicKey, signature: MultiEd25519Signature)   // 1
    case multiAgent(MultiAgentAuthenticator)                                            // 2
    case feePayer(FeePayerAuthenticator)                                                // 3
    case singleSender(AccountAuthenticator)                                             // 4

    private enum Variant: UInt32 {
        case ed25519 = 0
        case multiEd25519 = 1
        case multiAgent = 2
        case feePayer = 3
        case singleSender = 4
    }

    public func serialize(to serializer: inout Serializer) {
        switch self {
        case .ed25519(let pk, let sig):
            serializer.serializeU32AsUleb128(Variant.ed25519.rawValue)
            pk.serialize(to: &serializer)
            sig.serialize(to: &serializer)

        case .multiEd25519(let pk, let sig):
            serializer.serializeU32AsUleb128(Variant.multiEd25519.rawValue)
            pk.serialize(to: &serializer)
            sig.serialize(to: &serializer)

        case .multiAgent(let ma):
            serializer.serializeU32AsUleb128(Variant.multiAgent.rawValue)
            ma.serialize(to: &serializer)

        case .feePayer(let fp):
            serializer.serializeU32AsUleb128(Variant.feePayer.rawValue)
            fp.serialize(to: &serializer)

        case .singleSender(let auth):
            serializer.serializeU32AsUleb128(Variant.singleSender.rawValue)
            auth.serialize(to: &serializer)
        }
    }

    public static func deserialize(
        from deserializer: inout Deserializer
    ) throws -> TransactionAuthenticator {
        let variant = try deserializer.deserializeUleb128()
        switch variant {
        case Variant.ed25519.rawValue:
            let pk = try Ed25519PublicKey.deserialize(from: &deserializer)
            let sig = try Ed25519Signature.deserialize(from: &deserializer)
            return .ed25519(publicKey: pk, signature: sig)
        case Variant.multiEd25519.rawValue:
            let pk = try MultiEd25519PublicKey.deserialize(from: &deserializer)
            let sig = try MultiEd25519Signature.deserialize(from: &deserializer)
            return .multiEd25519(publicKey: pk, signature: sig)
        case Variant.multiAgent.rawValue:
            return .multiAgent(try MultiAgentAuthenticator.deserialize(from: &deserializer))
        case Variant.feePayer.rawValue:
            return .feePayer(try FeePayerAuthenticator.deserialize(from: &deserializer))
        case Variant.singleSender.rawValue:
            return .singleSender(try AccountAuthenticator.deserialize(from: &deserializer))
        default:
            throw AptosError.deserializationError(
                "Unknown TransactionAuthenticator variant: \(variant)"
            )
        }
    }
}

/// Multi-agent authenticator.
public struct MultiAgentAuthenticator: Serializable, Deserializable, Sendable, Hashable {
    public let senderAuthenticator: AccountAuthenticator
    public let secondarySignerAddresses: [AccountAddress]
    public let secondaryAuthenticators: [AccountAuthenticator]

    public func serialize(to serializer: inout Serializer) {
        senderAuthenticator.serialize(to: &serializer)
        serializer.serializeU32AsUleb128(UInt32(secondarySignerAddresses.count))
        for addr in secondarySignerAddresses { addr.serialize(to: &serializer) }
        serializer.serializeU32AsUleb128(UInt32(secondaryAuthenticators.count))
        for auth in secondaryAuthenticators { auth.serialize(to: &serializer) }
    }

    public static func deserialize(
        from deserializer: inout Deserializer
    ) throws -> MultiAgentAuthenticator {
        let sender = try AccountAuthenticator.deserialize(from: &deserializer)
        let addrCount = Int(try deserializer.deserializeUleb128())
        var addrs: [AccountAddress] = []
        for _ in 0 ..< addrCount { addrs.append(try AccountAddress.deserialize(from: &deserializer)) }
        let authCount = Int(try deserializer.deserializeUleb128())
        var auths: [AccountAuthenticator] = []
        for _ in 0 ..< authCount { auths.append(try AccountAuthenticator.deserialize(from: &deserializer)) }
        return MultiAgentAuthenticator(
            senderAuthenticator: sender,
            secondarySignerAddresses: addrs,
            secondaryAuthenticators: auths
        )
    }
}

/// Fee payer authenticator.
public struct FeePayerAuthenticator: Serializable, Deserializable, Sendable, Hashable {
    public let senderAuthenticator: AccountAuthenticator
    public let secondarySignerAddresses: [AccountAddress]
    public let secondaryAuthenticators: [AccountAuthenticator]
    public let feePayerAddress: AccountAddress
    public let feePayerAuthenticator: AccountAuthenticator

    public func serialize(to serializer: inout Serializer) {
        senderAuthenticator.serialize(to: &serializer)
        serializer.serializeU32AsUleb128(UInt32(secondarySignerAddresses.count))
        for addr in secondarySignerAddresses { addr.serialize(to: &serializer) }
        serializer.serializeU32AsUleb128(UInt32(secondaryAuthenticators.count))
        for auth in secondaryAuthenticators { auth.serialize(to: &serializer) }
        feePayerAddress.serialize(to: &serializer)
        feePayerAuthenticator.serialize(to: &serializer)
    }

    public static func deserialize(
        from deserializer: inout Deserializer
    ) throws -> FeePayerAuthenticator {
        let sender = try AccountAuthenticator.deserialize(from: &deserializer)
        let addrCount = Int(try deserializer.deserializeUleb128())
        var addrs: [AccountAddress] = []
        for _ in 0 ..< addrCount { addrs.append(try AccountAddress.deserialize(from: &deserializer)) }
        let authCount = Int(try deserializer.deserializeUleb128())
        var auths: [AccountAuthenticator] = []
        for _ in 0 ..< authCount { auths.append(try AccountAuthenticator.deserialize(from: &deserializer)) }
        let fpAddr = try AccountAddress.deserialize(from: &deserializer)
        let fpAuth = try AccountAuthenticator.deserialize(from: &deserializer)
        return FeePayerAuthenticator(
            senderAuthenticator: sender,
            secondarySignerAddresses: addrs,
            secondaryAuthenticators: auths,
            feePayerAddress: fpAddr,
            feePayerAuthenticator: fpAuth
        )
    }
}
