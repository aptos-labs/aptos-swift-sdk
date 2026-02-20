import Foundation

// MARK: - AccountAddress

/// Represents a 32-byte Aptos account address.
///
/// Addresses are displayed as hex strings with "0x" prefix.
/// Special addresses (0x0 through 0xf) use short form by default.
public struct AccountAddress: Sendable, Equatable, Hashable, Comparable {
    /// The raw 32-byte address data.
    public let data: Data

    /// The byte length of an account address.
    public static let length = 32

    // MARK: - Constants

    /// The zero address (0x0).
    public static let zero = Self(bytes: Data(repeating: 0, count: 32))!

    /// Address 0x1 (framework address).
    public static let one = Self(fromU8: 1)

    /// Address 0x3.
    public static let three = Self(fromU8: 3)

    /// Address 0x4.
    public static let four = Self(fromU8: 4)

    // MARK: - Initialization

    /// Creates an address from exactly 32 raw bytes.
    public init?(bytes: Data) {
        guard bytes.count == Self.length else { return nil }
        data = bytes
    }

    /// Creates an address from a byte array.
    public init?(bytes: [UInt8]) {
        guard bytes.count == Self.length else { return nil }
        data = Data(bytes)
    }

    /// Creates an address from a single byte value (padded to 32 bytes).
    private init(fromU8 value: UInt8) {
        var bytes = Data(repeating: 0, count: Self.length)
        bytes[Self.length - 1] = value
        data = bytes
    }

    /// Creates an address from a hex string (with or without "0x" prefix).
    ///
    /// The hex string is left-padded with zeros to 32 bytes if needed.
    public static func fromHex(_ hex: String) throws -> Self {
        let stripped = Hex.stripPrefix(hex)
        guard !stripped.isEmpty else {
            throw AptosError.parse(.invalidAddress("Empty address string"))
        }

        // Pad to 64 hex chars (32 bytes)
        let padded: String
        if stripped.count > 64 {
            throw AptosError.parse(.invalidAddress(
                "Address hex string too long: \(stripped.count) chars (max 64)"
            ))
        } else if stripped.count < 64 {
            padded = String(repeating: "0", count: 64 - stripped.count) + stripped
        } else {
            padded = stripped
        }

        let decoded = try Hex.decode(padded)
        guard decoded.count == Self.length else {
            throw AptosError.parse(.invalidAddress("Invalid address byte length: \(decoded.count)"))
        }
        return Self(bytes: decoded)!
    }

    /// Creates an address from a string that could be a hex address or a special name.
    public static func from(_ input: String) throws -> Self {
        try fromHex(input)
    }

    /// Creates an address from another AccountAddress (identity).
    public static func from(_ address: Self) -> Self {
        address
    }

    // MARK: - Display

    /// Returns the full hex representation with "0x" prefix (64 hex chars).
    public func toHex() -> String {
        Hex.encode(data)
    }

    /// Returns the short hex representation where leading zeros are omitted.
    ///
    /// Special addresses (0x0-0xf, all addresses with 63+ leading zero nibbles)
    /// are shown in short form: "0x0", "0x1", etc.
    public func toShortString() -> String {
        let hex = Hex.encodeWithoutPrefix(data)
        // Find first non-zero char
        let trimmed = String(hex.drop { $0 == "0" })
        if trimmed.isEmpty {
            return "0x0"
        }
        return "0x" + trimmed
    }

    /// Returns true if this is a "special" address (last byte 0x00-0x0f, rest zeros).
    public var isSpecial: Bool {
        // All bytes except the last must be zero, and last byte must be <= 0xf
        for i in 0 ..< (Self.length - 1) {
            if data[i] != 0 { return false }
        }
        return data[Self.length - 1] <= 0x0F
    }

    // MARK: - Comparable

    public static func < (lhs: Self, rhs: Self) -> Bool {
        for i in 0 ..< length {
            if lhs.data[i] < rhs.data[i] { return true }
            if lhs.data[i] > rhs.data[i] { return false }
        }
        return false
    }
}

// MARK: BCSSerializable, BCSDeserializable

extension AccountAddress: BCSSerializable, BCSDeserializable {
    public func serialize(to serializer: inout Serializer) throws {
        serializer.serializeFixedBytes(data)
    }

    public static func deserialize(from deserializer: inout Deserializer) throws -> AccountAddress {
        let bytes = try deserializer.deserializeFixedBytes(count: Self.length)
        guard let address = AccountAddress(bytes: bytes) else {
            throw AptosError.serialization(.invalidData("Invalid account address bytes"))
        }
        return address
    }
}

// MARK: Codable

extension AccountAddress: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let hex = try container.decode(String.self)
        self = try AccountAddress.fromHex(hex)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(toHex())
    }
}

// MARK: CustomStringConvertible

extension AccountAddress: CustomStringConvertible {
    public var description: String {
        if isSpecial {
            return toShortString()
        }
        return toHex()
    }
}

// MARK: CustomDebugStringConvertible

extension AccountAddress: CustomDebugStringConvertible {
    public var debugDescription: String {
        "AccountAddress(\(toHex()))"
    }
}
