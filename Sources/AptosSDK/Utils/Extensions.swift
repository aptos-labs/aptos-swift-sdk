import Foundation

// MARK: - SHA3-256

/// Compute SHA3-256 hash.
public func sha3_256(_ data: Data) -> Data {
    SHA3.sha256(data)
}

/// Compute SHA3-256 of a domain-separated message.
public func hashWithSalt(_ salt: String, _ message: Data) -> Data {
    var input = Data()
    // BCS-serialize the salt as a string (ULEB128 length + UTF-8 bytes)
    var serializer = Serializer()
    serializer.serializeStr(salt)
    input.append(serializer.output())
    input.append(message)
    return sha3_256(input)
}

// MARK: - Data Extensions

extension Data {
    /// Create Data from a hex string.
    public init(hex: String) throws {
        self = try Hex.decode(hex)
    }

    /// Convert to hex string with 0x prefix.
    public var hexEncodedString: String {
        Hex.encode(self)
    }
}
