import Foundation

/// Hex encoding/decoding utility wrapping raw bytes.
public struct Hex: Sendable, Hashable, Equatable {
    /// The underlying raw bytes.
    public let data: Data

    public init(data: Data) {
        self.data = data
    }

    /// Create from a hex string (with or without `0x` prefix).
    public init(_ hexString: String) throws {
        self.data = try Self.decode(hexString)
    }

    /// Hex string with `0x` prefix.
    public func toString() -> String {
        "0x" + toStringWithoutPrefix()
    }

    /// Hex string without prefix.
    public func toStringWithoutPrefix() -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }

    /// Decode a hex string to bytes.
    public static func decode(_ hexString: String) throws -> Data {
        var hex = hexString
        if hex.hasPrefix("0x") || hex.hasPrefix("0X") {
            hex = String(hex.dropFirst(2))
        }
        if hex.count % 2 != 0 {
            // Pad with leading zero for odd-length
            hex = "0" + hex
        }
        var data = Data(capacity: hex.count / 2)
        var index = hex.startIndex
        while index < hex.endIndex {
            let nextIndex = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index ..< nextIndex], radix: 16) else {
                throw AptosError.invalidArgument("Invalid hex character in: \(hexString)")
            }
            data.append(byte)
            index = nextIndex
        }
        return data
    }

    /// Encode bytes to hex string with `0x` prefix.
    public static func encode(_ data: Data) -> String {
        "0x" + data.map { String(format: "%02x", $0) }.joined()
    }
}

extension Hex: CustomStringConvertible {
    public var description: String { toString() }
}

extension Hex: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let hexString = try container.decode(String.self)
        try self.init(hexString)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(toString())
    }
}
