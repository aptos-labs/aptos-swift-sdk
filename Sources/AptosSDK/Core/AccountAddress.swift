import Foundation

/// The length of an Aptos account address in bytes.
public let ADDRESS_LENGTH = 32

/// A 32-byte Aptos account address.
///
/// Addresses are represented as fixed-length 32-byte values. String representation uses
/// hexadecimal encoding with a `0x` prefix. Addresses 0x0 through 0xf are "special"
/// and use a short form (e.g. `"0x1"`) by default; all others use the full 64-hex-digit
/// long form.
public struct AccountAddress: Sendable, Hashable, Equatable {

    // MARK: - Storage

    /// The raw 32 bytes of this address.
    public let data: Data

    // MARK: - Constants

    /// The all-zeros address.
    public static let ZERO = AccountAddress(padded: Data(repeating: 0, count: ADDRESS_LENGTH))

    /// The address `0x1` (Aptos framework).
    public static let ONE = AccountAddress(padded: Data([
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 1,
    ]))

    /// The address `0x3`.
    public static let THREE = AccountAddress(padded: Data([
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 3,
    ]))

    /// The address `0x4`.
    public static let FOUR = AccountAddress(padded: Data([
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 4,
    ]))

    // MARK: - Initializers

    /// Internal designated initializer. `data` must be exactly 32 bytes.
    private init(padded data: Data) {
        precondition(data.count == ADDRESS_LENGTH, "AccountAddress must be exactly 32 bytes")
        self.data = data
    }

    /// Create from exactly 32 raw bytes.
    ///
    /// - Throws: `AptosError.invalidArgument` if `bytes` is not 32 bytes.
    public init(bytes: Data) throws {
        guard bytes.count == ADDRESS_LENGTH else {
            throw AptosError.invalidArgument(
                "AccountAddress must be exactly \(ADDRESS_LENGTH) bytes, got \(bytes.count)"
            )
        }
        self.data = bytes
    }

    // MARK: - Factory Methods

    /// Create an `AccountAddress` from a `String` or an existing `AccountAddress`.
    ///
    /// When `input` is a `String` it is parsed as a hex address (with or without the `0x` prefix).
    /// Short hex strings (fewer than 64 hex digits after the prefix) are left-padded with zeros to
    /// reach 32 bytes, mirroring the behaviour of the TypeScript SDK.
    ///
    /// - Throws: `AptosError.invalidArgument` if the input is not a valid address.
    public static func from(_ input: some AccountAddressInput) throws -> AccountAddress {
        try input.toAccountAddress()
    }

    /// Parse from a hex string (with or without `0x` prefix, and with or without leading zeros).
    ///
    /// - Throws: `AptosError.invalidArgument` if the string is not valid hex or is too long.
    public static func fromString(_ hexString: String) throws -> AccountAddress {
        var hex = hexString
        if hex.hasPrefix("0x") || hex.hasPrefix("0X") {
            hex = String(hex.dropFirst(2))
        }

        // A valid address may not contain more than 64 hex digits (32 bytes).
        guard hex.count <= 64 else {
            throw AptosError.invalidArgument(
                "AccountAddress hex string is too long: '\(hexString)' (max 64 hex chars after prefix)"
            )
        }

        // Pad to 64 hex characters (32 bytes).
        let padded = String(repeating: "0", count: 64 - hex.count) + hex

        guard let bytes = Data(hexEncoded: padded) else {
            throw AptosError.invalidArgument(
                "AccountAddress contains invalid hex characters: '\(hexString)'"
            )
        }

        return AccountAddress(padded: bytes)
    }

    /// Create from exactly 32 bytes of raw `Data`, without copying.
    ///
    /// - Throws: `AptosError.invalidArgument` if `data` is not 32 bytes.
    public static func fromData(_ data: Data) throws -> AccountAddress {
        try AccountAddress(bytes: data)
    }

    // MARK: - String Representations

    /// Whether this address is a "special" address (0x0 – 0xf).
    ///
    /// Special addresses have all but the final byte equal to zero, and the final byte
    /// is in the range 0–15.
    public var isSpecial: Bool {
        // All leading 31 bytes must be zero.
        guard data.prefix(ADDRESS_LENGTH - 1).allSatisfy({ $0 == 0 }) else {
            return false
        }
        // The last byte must be 0x00–0x0f.
        return data[ADDRESS_LENGTH - 1] <= 0x0F
    }

    /// The canonical short-form hex string (leading zeros stripped, `0x` prefix).
    ///
    /// Special addresses (0x0–0xf) always return the single-digit short form such as `"0x0"`.
    /// Non-special addresses return the full 64-digit long form.
    public func toStringShort() -> String {
        if isSpecial {
            // Emit a single hex digit for the last byte.
            return "0x" + String(format: "%x", data[ADDRESS_LENGTH - 1])
        }
        return toStringLong()
    }

    /// The canonical long-form hex string (all 64 hex digits, `0x` prefix).
    public func toStringLong() -> String {
        "0x" + data.map { String(format: "%02x", $0) }.joined()
    }

    /// Default string representation (long form).
    public func toString() -> String {
        toStringLong()
    }

    // MARK: - Equatable / Hashable

    public static func == (lhs: AccountAddress, rhs: AccountAddress) -> Bool {
        lhs.data == rhs.data
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(data)
    }
}

// MARK: - CustomStringConvertible

extension AccountAddress: CustomStringConvertible {
    /// Returns the short form for special addresses, long form otherwise.
    public var description: String { toStringShort() }
}

// MARK: - Codable

extension AccountAddress: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let hexString = try container.decode(String.self)
        do {
            self = try AccountAddress.fromString(hexString)
        } catch {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid AccountAddress hex string: '\(hexString)'"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(toStringLong())
    }
}

// MARK: - Serializable / Deserializable

extension AccountAddress: Serializable {
    /// BCS-serialize as a fixed 32-byte value (no length prefix).
    public func serialize(to serializer: inout Serializer) {
        serializer.serializeFixedBytes(data)
    }
}

extension AccountAddress: Deserializable {
    /// BCS-deserialize from exactly 32 bytes.
    public static func deserialize(from deserializer: inout Deserializer) throws -> AccountAddress {
        let bytes = try deserializer.deserializeFixedBytes(ADDRESS_LENGTH)
        return AccountAddress(padded: bytes)
    }
}

// MARK: - AccountAddressInput Protocol

/// Types that can be converted to an `AccountAddress`.
public protocol AccountAddressInput {
    func toAccountAddress() throws -> AccountAddress
}

extension AccountAddress: AccountAddressInput {
    public func toAccountAddress() throws -> AccountAddress { self }
}

extension String: AccountAddressInput {
    public func toAccountAddress() throws -> AccountAddress {
        try AccountAddress.fromString(self)
    }
}

// MARK: - Private Helpers

private extension Data {
    /// Decode an even-length hex string into `Data`. Returns `nil` on invalid input.
    init?(hexEncoded string: String) {
        guard string.count % 2 == 0 else { return nil }
        var data = Data(capacity: string.count / 2)
        var index = string.startIndex
        while index < string.endIndex {
            let next = string.index(index, offsetBy: 2)
            guard let byte = UInt8(string[index ..< next], radix: 16) else { return nil }
            data.append(byte)
            index = next
        }
        self = data
    }
}
