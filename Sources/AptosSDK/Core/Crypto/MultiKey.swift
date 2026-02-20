import Foundation

/// M-of-N multi-key public key.
///
/// Contains a list of `AnyPublicKey` values and a threshold (`signaturesRequired`).
/// At least `signaturesRequired` of the keys must sign a transaction for it to be valid.
public struct MultiKey: Serializable, Deserializable, Sendable, Hashable {
    /// The list of public keys.
    public let publicKeys: [AnyPublicKey]

    /// Number of signatures required (M of N).
    public let signaturesRequired: UInt8

    public init(publicKeys: [AnyPublicKey], signaturesRequired: UInt8) throws {
        guard !publicKeys.isEmpty else {
            throw AptosError.invalidArgument("MultiKey requires at least one public key")
        }
        guard signaturesRequired > 0, signaturesRequired <= UInt8(publicKeys.count) else {
            throw AptosError.invalidArgument(
                "signaturesRequired must be between 1 and \(publicKeys.count), got \(signaturesRequired)"
            )
        }
        self.publicKeys = publicKeys
        self.signaturesRequired = signaturesRequired
    }

    /// Derive the authentication key for this multi-key.
    public func authKey() -> AuthenticationKey {
        AuthenticationKey.fromMultiKey(self)
    }

    // MARK: - Serializable

    public func serialize(to serializer: inout Serializer) {
        serializer.serializeU32AsUleb128(UInt32(publicKeys.count))
        for key in publicKeys {
            key.serialize(to: &serializer)
        }
        serializer.serializeU8(signaturesRequired)
    }

    // MARK: - Deserializable

    public static func deserialize(from deserializer: inout Deserializer) throws -> MultiKey {
        let count = Int(try deserializer.deserializeUleb128())
        var keys: [AnyPublicKey] = []
        keys.reserveCapacity(count)
        for _ in 0 ..< count {
            keys.append(try AnyPublicKey.deserialize(from: &deserializer))
        }
        let threshold = try deserializer.deserializeU8()
        return try MultiKey(publicKeys: keys, signaturesRequired: threshold)
    }
}

/// Multi-key signature containing individual signatures and a bitmap indicating which keys signed.
public struct MultiKeySignature: AccountSignature, Deserializable {
    /// The individual signatures (one per signer that signed).
    public let signatures: [AnySignature]

    /// Bitmap indicating which public key indices have corresponding signatures.
    /// Each bit position corresponds to a key index in the MultiKey.publicKeys array.
    public let bitmap: Data

    /// BCS-encoded representation of this multi-key signature.
    public var data: Data { bcsToBytes() }

    public init(signatures: [AnySignature], bitmap: Data) {
        self.signatures = signatures
        self.bitmap = bitmap
    }

    /// Create from signatures with their signer indices.
    public static func create(
        signatures: [(index: Int, signature: AnySignature)],
        totalKeys: Int
    ) -> MultiKeySignature {
        let sorted = signatures.sorted { $0.index < $1.index }
        let bitmapByteCount = (totalKeys + 7) / 8
        var bitmapBytes = Data(repeating: 0, count: bitmapByteCount)
        for (index, _) in sorted {
            let byteIndex = index / 8
            let bitIndex = 7 - (index % 8)
            bitmapBytes[byteIndex] |= (1 << bitIndex)
        }
        return MultiKeySignature(
            signatures: sorted.map(\.signature),
            bitmap: bitmapBytes
        )
    }

    // MARK: - Serializable

    public func serialize(to serializer: inout Serializer) {
        serializer.serializeU32AsUleb128(UInt32(signatures.count))
        for sig in signatures {
            sig.serialize(to: &serializer)
        }
        serializer.serializeBytes(bitmap)
    }

    // MARK: - Deserializable

    public static func deserialize(from deserializer: inout Deserializer) throws -> MultiKeySignature {
        let count = Int(try deserializer.deserializeUleb128())
        var sigs: [AnySignature] = []
        sigs.reserveCapacity(count)
        for _ in 0 ..< count {
            sigs.append(try AnySignature.deserialize(from: &deserializer))
        }
        let bitmap = try deserializer.deserializeBytes()
        return MultiKeySignature(signatures: sigs, bitmap: bitmap)
    }
}

// MARK: - Legacy MultiEd25519

/// Legacy M-of-N Ed25519 public key.
public struct MultiEd25519PublicKey: AccountPublicKey {
    public let publicKeys: [Ed25519PublicKey]
    public let threshold: UInt8

    public var data: Data {
        var result = Data()
        for key in publicKeys {
            result.append(key.data)
        }
        result.append(threshold)
        return result
    }

    public init(publicKeys: [Ed25519PublicKey], threshold: UInt8) throws {
        guard !publicKeys.isEmpty, threshold > 0, threshold <= UInt8(publicKeys.count) else {
            throw AptosError.invalidArgument("Invalid MultiEd25519 threshold")
        }
        self.publicKeys = publicKeys
        self.threshold = threshold
    }

    public func verify(message: Data, signature: any AccountSignature) throws -> Bool {
        // Multi-Ed25519 verification is handled by the chain
        throw AptosError.cryptoError("Multi-Ed25519 off-chain verification not supported")
    }

    public func serialize(to serializer: inout Serializer) {
        serializer.serializeBytes(data)
    }

    public static func deserialize(from deserializer: inout Deserializer) throws -> MultiEd25519PublicKey {
        let bytes = try deserializer.deserializeBytes()
        guard bytes.count >= 33 else {
            throw AptosError.deserializationError("MultiEd25519PublicKey too short")
        }
        let threshold = bytes[bytes.count - 1]
        let keyCount = (bytes.count - 1) / Ed25519PublicKey.length
        var keys: [Ed25519PublicKey] = []
        for i in 0 ..< keyCount {
            let start = i * Ed25519PublicKey.length
            let end = start + Ed25519PublicKey.length
            keys.append(try Ed25519PublicKey(data: bytes[start ..< end]))
        }
        return try MultiEd25519PublicKey(publicKeys: keys, threshold: threshold)
    }

    public static func == (lhs: MultiEd25519PublicKey, rhs: MultiEd25519PublicKey) -> Bool {
        lhs.data == rhs.data
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(data)
    }
}

/// Legacy MultiEd25519 signature.
public struct MultiEd25519Signature: AccountSignature {
    public let signatures: [Ed25519Signature]
    public let bitmap: Data
    public var data: Data {
        var result = Data()
        for sig in signatures {
            result.append(sig.data)
        }
        result.append(bitmap)
        return result
    }

    public func serialize(to serializer: inout Serializer) {
        serializer.serializeBytes(data)
    }

    public static func deserialize(from deserializer: inout Deserializer) throws -> MultiEd25519Signature {
        let bytes = try deserializer.deserializeBytes()
        guard bytes.count >= 4 else {
            throw AptosError.deserializationError("MultiEd25519Signature too short")
        }
        let bitmap = bytes.suffix(4)
        let sigBytes = bytes.prefix(bytes.count - 4)
        let sigCount = sigBytes.count / Ed25519Signature.length
        var sigs: [Ed25519Signature] = []
        for i in 0 ..< sigCount {
            let start = i * Ed25519Signature.length
            let end = start + Ed25519Signature.length
            sigs.append(try Ed25519Signature(data: Data(sigBytes[start ..< end])))
        }
        return MultiEd25519Signature(signatures: sigs, bitmap: Data(bitmap))
    }

    public static func == (lhs: MultiEd25519Signature, rhs: MultiEd25519Signature) -> Bool {
        lhs.data == rhs.data
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(data)
    }
}
