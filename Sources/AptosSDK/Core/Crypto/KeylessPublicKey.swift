import Foundation

/// A keyless public key for OIDC-based authentication.
///
/// Constructed from the issuer (iss) and an identity commitment.
public struct KeylessPublicKey: Sendable, Equatable, Hashable {
    /// The raw serialized key data.
    public let data: Data

    /// The OIDC issuer (e.g., "https://accounts.google.com").
    public let issuer: String

    /// The identity commitment (hash of uid + pepper).
    public let idCommitment: Data

    public init(issuer: String, idCommitment: Data) {
        self.issuer = issuer
        self.idCommitment = idCommitment
        // The raw data is just the BCS of the fields
        var bytes = Data()
        bytes.append(contentsOf: issuer.utf8)
        bytes.append(idCommitment)
        self.data = bytes
    }
}

extension KeylessPublicKey: BCSSerializable, BCSDeserializable {
    public func serialize(to serializer: inout Serializer) throws {
        try serializer.serializeStr(issuer)
        try serializer.serializeBytes(idCommitment)
    }

    public static func deserialize(from deserializer: inout Deserializer) throws -> KeylessPublicKey {
        let issuer = try deserializer.deserializeStr()
        let idCommitment = try deserializer.deserializeBytes()
        return KeylessPublicKey(issuer: issuer, idCommitment: idCommitment)
    }
}
