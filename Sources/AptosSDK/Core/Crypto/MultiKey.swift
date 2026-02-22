import Foundation

// MARK: - MultiKey

/// A multi-key public key supporting M-of-N signatures with mixed key types.
public struct MultiKey: Sendable, Equatable {
    /// The public keys in this multi-key.
    public let publicKeys: [AnyPublicKey]

    /// The number of signatures required.
    public let signaturesRequired: UInt8

    /// Maximum number of keys allowed by the 4-byte bitmap encoding.
    public static let maxKeys = 32

    /// Creates a new MultiKey.
    public init(publicKeys: [AnyPublicKey], signaturesRequired: UInt8) throws {
        guard !publicKeys.isEmpty else {
            throw AptosError.multiSignature(.invalidThreshold(
                message: "MultiKey requires at least one public key"
            ))
        }
        guard publicKeys.count <= Self.maxKeys else {
            throw AptosError.multiSignature(.tooManyKeys(
                count: publicKeys.count, maximum: Self.maxKeys
            ))
        }
        guard signaturesRequired > 0, signaturesRequired <= publicKeys.count else {
            throw AptosError.multiSignature(.invalidThreshold(
                message: "signaturesRequired (\(signaturesRequired)) must be between 1 and \(publicKeys.count)"
            ))
        }
        self.publicKeys = publicKeys
        self.signaturesRequired = signaturesRequired
    }
}

// MARK: BCSSerializable, BCSDeserializable

extension MultiKey: BCSSerializable, BCSDeserializable {
    public func serialize(to serializer: inout Serializer) throws {
        try serializer.serializeVector(publicKeys)
        serializer.serializeU8(signaturesRequired)
    }

    public static func deserialize(from deserializer: inout Deserializer) throws -> MultiKey {
        let keys = try deserializer.deserializeVector(AnyPublicKey.self)
        let required = try deserializer.deserializeU8()
        return try MultiKey(publicKeys: keys, signaturesRequired: required)
    }
}

// MARK: - MultiKeySignature

/// A multi-signature composed of indexed signatures from a MultiKey.
public struct MultiKeySignature: Sendable, Equatable {
    /// The individual signatures.
    public let signatures: [AnySignature]

    /// Bitmap indicating which key indices signed.
    public let bitmap: Data

    /// Creates a MultiKeySignature.
    public init(signatures: [AnySignature], bitmap: Data) {
        self.signatures = signatures
        self.bitmap = bitmap
    }

    /// Creates a MultiKeySignature from signatures and their key indices.
    ///
    /// This method preserves legacy behavior and does not validate duplicate or
    /// out-of-range indices. For validated construction, use
    /// `validatedFromSignaturesWithIndices(...)`.
    public static func fromSignaturesWithIndices(
        signatures: [(index: Int, signature: AnySignature)],
        totalKeys _: Int
    ) -> Self {
        let sorted = signatures.sorted { $0.index < $1.index }
        var bitmapBytes = [UInt8](repeating: 0, count: 4)
        for entry in sorted {
            let byteIndex = entry.index / 8
            let bitIndex = entry.index % 8
            if byteIndex < 4 {
                bitmapBytes[byteIndex] |= (1 << (7 - bitIndex))
            }
        }
        return Self(
            signatures: sorted.map(\.signature),
            bitmap: Data(bitmapBytes)
        )
    }

    /// Creates a MultiKeySignature from signatures and their key indices with validation.
    public static func validatedFromSignaturesWithIndices(
        signatures: [(index: Int, signature: AnySignature)],
        totalKeys: Int
    ) throws -> Self {
        guard totalKeys > 0 else {
            throw AptosError.multiSignature(.invalidThreshold(
                message: "totalKeys must be greater than zero"
            ))
        }
        guard totalKeys <= MultiKey.maxKeys else {
            throw AptosError.multiSignature(.tooManyKeys(
                count: totalKeys, maximum: MultiKey.maxKeys
            ))
        }

        var seen = Set<Int>()
        for entry in signatures {
            guard entry.index >= 0, entry.index < totalKeys else {
                throw AptosError.multiSignature(.invalidSignerIndex(
                    index: entry.index, totalKeys: totalKeys
                ))
            }
            guard seen.insert(entry.index).inserted else {
                throw AptosError.multiSignature(.duplicateSignerIndex(index: entry.index))
            }
        }

        return fromSignaturesWithIndices(signatures: signatures, totalKeys: totalKeys)
    }
}

// MARK: BCSSerializable, BCSDeserializable

extension MultiKeySignature: BCSSerializable, BCSDeserializable {
    public func serialize(to serializer: inout Serializer) throws {
        try serializer.serializeVector(signatures)
        serializer.serializeFixedBytes(bitmap)
    }

    public static func deserialize(from deserializer: inout Deserializer) throws -> MultiKeySignature {
        let sigs = try deserializer.deserializeVector(AnySignature.self)
        let bitmap = try deserializer.deserializeFixedBytes(count: 4)
        return MultiKeySignature(signatures: sigs, bitmap: bitmap)
    }
}

// MARK: - MultiEd25519PublicKey

/// Legacy M-of-N Ed25519 multi-signature public key.
public struct MultiEd25519PublicKey: Sendable, Equatable {
    public let publicKeys: [Ed25519PublicKey]
    public let threshold: UInt8

    /// Maximum number of keys allowed in a MultiEd25519 public key.
    public static let maxKeys = 32

    public init(publicKeys: [Ed25519PublicKey], threshold: UInt8) throws {
        guard !publicKeys.isEmpty else {
            throw AptosError.multiSignature(.invalidThreshold(
                message: "MultiEd25519 requires at least one key"
            ))
        }
        guard publicKeys.count <= Self.maxKeys else {
            throw AptosError.multiSignature(.tooManyKeys(
                count: publicKeys.count, maximum: Self.maxKeys
            ))
        }
        guard threshold > 0, threshold <= publicKeys.count else {
            throw AptosError.multiSignature(.invalidThreshold(
                message: "threshold (\(threshold)) must be between 1 and \(publicKeys.count)"
            ))
        }
        self.publicKeys = publicKeys
        self.threshold = threshold
    }
}

// MARK: BCSSerializable, BCSDeserializable

extension MultiEd25519PublicKey: BCSSerializable, BCSDeserializable {
    public func serialize(to serializer: inout Serializer) throws {
        // MultiEd25519 serializes as: [all public key bytes concatenated] [threshold as u8]
        var allBytes = Data()
        for key in publicKeys {
            allBytes.append(key.data)
        }
        try serializer.serializeBytes(allBytes)
        serializer.serializeU8(threshold)
    }

    public static func deserialize(from deserializer: inout Deserializer) throws -> MultiEd25519PublicKey {
        let allBytes = try deserializer.deserializeBytes()
        let threshold = try deserializer.deserializeU8()
        guard allBytes.count % Ed25519PublicKey.length == 0 else {
            throw AptosError.serialization(.invalidData("Invalid MultiEd25519 key bytes"))
        }
        let count = allBytes.count / Ed25519PublicKey.length
        var keys = [Ed25519PublicKey]()
        for i in 0 ..< count {
            let start = i * Ed25519PublicKey.length
            let end = start + Ed25519PublicKey.length
            let keyData = allBytes[start ..< end]
            keys.append(try Ed25519PublicKey(data: Data(keyData)))
        }
        return try MultiEd25519PublicKey(publicKeys: keys, threshold: threshold)
    }
}

// MARK: - MultiEd25519Signature

/// Legacy multi-Ed25519 signature.
public struct MultiEd25519Signature: Sendable, Equatable {
    public let signatures: [Ed25519Signature]
    public let bitmap: Data

    public init(signatures: [Ed25519Signature], bitmap: Data) {
        self.signatures = signatures
        self.bitmap = bitmap
    }

    /// Creates a MultiEd25519Signature from signatures and their key indices.
    public static func fromSignaturesWithIndices(
        signatures: [(index: Int, signature: Ed25519Signature)],
        totalKeys: Int
    ) throws -> Self {
        // Validate no duplicate indices
        var seen = Set<Int>()
        for entry in signatures {
            guard entry.index >= 0, entry.index < totalKeys else {
                throw AptosError.multiSignature(.invalidSignerIndex(
                    index: entry.index, totalKeys: totalKeys
                ))
            }
            guard seen.insert(entry.index).inserted else {
                throw AptosError.multiSignature(.duplicateSignerIndex(index: entry.index))
            }
        }

        let sorted = signatures.sorted { $0.index < $1.index }
        var bitmapBytes = [UInt8](repeating: 0, count: 4)
        for entry in sorted {
            let byteIndex = entry.index / 8
            let bitIndex = entry.index % 8
            if byteIndex < 4 {
                bitmapBytes[byteIndex] |= (1 << (7 - bitIndex))
            }
        }
        return Self(
            signatures: sorted.map(\.signature),
            bitmap: Data(bitmapBytes)
        )
    }
}

// MARK: BCSSerializable, BCSDeserializable

extension MultiEd25519Signature: BCSSerializable, BCSDeserializable {
    public func serialize(to serializer: inout Serializer) throws {
        var allBytes = Data()
        for sig in signatures {
            allBytes.append(sig.data)
        }
        allBytes.append(bitmap)
        try serializer.serializeBytes(allBytes)
    }

    public static func deserialize(from deserializer: inout Deserializer) throws -> MultiEd25519Signature {
        let allBytes = try deserializer.deserializeBytes()
        guard allBytes.count >= 4 else {
            throw AptosError.serialization(.invalidData("MultiEd25519Signature too short"))
        }
        let bitmap = allBytes.suffix(4)
        let sigBytes = allBytes.prefix(allBytes.count - 4)
        guard sigBytes.count % Ed25519Signature.length == 0 else {
            throw AptosError.serialization(.invalidData("Invalid MultiEd25519 signature bytes"))
        }
        let count = sigBytes.count / Ed25519Signature.length
        var sigs = [Ed25519Signature]()
        for i in 0 ..< count {
            let start = i * Ed25519Signature.length
            let end = start + Ed25519Signature.length
            sigs.append(try Ed25519Signature(data: Data(sigBytes[start ..< end])))
        }
        return MultiEd25519Signature(signatures: sigs, bitmap: Data(bitmap))
    }
}
