import Foundation

/// A keyless public key derived from an OIDC issuer and identity commitment.
public struct KeylessPublicKey: AccountPublicKey {
    /// The OIDC issuer (e.g. "https://accounts.google.com").
    public let iss: String

    /// The identity commitment (Poseidon hash of pepper, aud, uid_val, uid_key).
    public let idCommitment: Data

    public var data: Data {
        var result = Data()
        let issData = Data(iss.utf8)
        result.append(contentsOf: withUnsafeBytes(of: UInt32(issData.count).littleEndian) { Data($0) })
        result.append(issData)
        result.append(idCommitment)
        return result
    }

    public init(iss: String, idCommitment: Data) {
        self.iss = iss
        self.idCommitment = idCommitment
    }

    public func verify(message: Data, signature: any AccountSignature) throws -> Bool {
        throw AptosError.cryptoError("Keyless verification is handled on-chain")
    }

    public func serialize(to serializer: inout Serializer) {
        serializer.serializeStr(iss)
        serializer.serializeBytes(idCommitment)
    }

    public static func deserialize(from deserializer: inout Deserializer) throws -> KeylessPublicKey {
        let iss = try deserializer.deserializeStr()
        let idCommitment = try deserializer.deserializeBytes()
        return KeylessPublicKey(iss: iss, idCommitment: idCommitment)
    }

    public static func == (lhs: KeylessPublicKey, rhs: KeylessPublicKey) -> Bool {
        lhs.iss == rhs.iss && lhs.idCommitment == rhs.idCommitment
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(iss)
        hasher.combine(idCommitment)
    }
}

/// A federated keyless public key with a custom JWK address.
public struct FederatedKeylessPublicKey: AccountPublicKey {
    public let keylessPublicKey: KeylessPublicKey
    public let jwkAddress: AccountAddress

    public var data: Data {
        var result = keylessPublicKey.data
        result.append(jwkAddress.data)
        return result
    }

    public var iss: String { keylessPublicKey.iss }
    public var idCommitment: Data { keylessPublicKey.idCommitment }

    public init(iss: String, idCommitment: Data, jwkAddress: AccountAddress) {
        self.keylessPublicKey = KeylessPublicKey(iss: iss, idCommitment: idCommitment)
        self.jwkAddress = jwkAddress
    }

    public func verify(message: Data, signature: any AccountSignature) throws -> Bool {
        throw AptosError.cryptoError("Federated keyless verification is handled on-chain")
    }

    public func serialize(to serializer: inout Serializer) {
        keylessPublicKey.serialize(to: &serializer)
        jwkAddress.serialize(to: &serializer)
    }

    public static func deserialize(
        from deserializer: inout Deserializer
    ) throws -> FederatedKeylessPublicKey {
        let inner = try KeylessPublicKey.deserialize(from: &deserializer)
        let addr = try AccountAddress.deserialize(from: &deserializer)
        return FederatedKeylessPublicKey(
            iss: inner.iss, idCommitment: inner.idCommitment, jwkAddress: addr
        )
    }

    public static func == (lhs: FederatedKeylessPublicKey, rhs: FederatedKeylessPublicKey) -> Bool {
        lhs.keylessPublicKey == rhs.keylessPublicKey && lhs.jwkAddress == rhs.jwkAddress
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(keylessPublicKey)
        hasher.combine(jwkAddress)
    }
}

/// A keyless signature (ZK proof + ephemeral signature).
public struct KeylessSignature: Serializable, Deserializable, Sendable, Hashable {
    public let data: Data

    public init(data: Data) {
        self.data = data
    }

    public func serialize(to serializer: inout Serializer) {
        serializer.serializeBytes(data)
    }

    public static func deserialize(from deserializer: inout Deserializer) throws -> KeylessSignature {
        let bytes = try deserializer.deserializeBytes()
        return KeylessSignature(data: bytes)
    }
}
