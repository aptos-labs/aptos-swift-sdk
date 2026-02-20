import Foundation

/// Utilities for hex encoding and decoding.
public enum Hex {
    /// Hex characters lookup table.
    private static let hexChars = Array("0123456789abcdef".unicodeScalars)

    /// Encodes bytes to a hex string with "0x" prefix.
    public static func encode(_ data: Data) -> String {
        "0x" + encodeWithoutPrefix(data)
    }

    /// Encodes bytes to a hex string with "0x" prefix.
    public static func encode(_ bytes: [UInt8]) -> String {
        "0x" + encodeWithoutPrefix(bytes)
    }

    /// Encodes bytes to a hex string without prefix.
    public static func encodeWithoutPrefix(_ data: Data) -> String {
        encodeWithoutPrefix(Array(data))
    }

    /// Encodes bytes to a hex string without prefix.
    public static func encodeWithoutPrefix(_ bytes: [UInt8]) -> String {
        var result = ""
        result.reserveCapacity(bytes.count * 2)
        for byte in bytes {
            result.unicodeScalars.append(hexChars[Int(byte >> 4)])
            result.unicodeScalars.append(hexChars[Int(byte & 0x0F)])
        }
        return result
    }

    /// Decodes a hex string (with or without "0x" prefix) to bytes.
    public static func decode(_ hex: String) throws -> Data {
        var str = hex
        if str.hasPrefix("0x") || str.hasPrefix("0X") {
            str = String(str.dropFirst(2))
        }

        if str.count % 2 != 0 {
            // Left-pad with zero for odd-length hex
            str = "0" + str
        }

        var data = Data(capacity: str.count / 2)
        var index = str.startIndex

        while index < str.endIndex {
            let nextIndex = str.index(index, offsetBy: 2)
            let byteStr = str[index..<nextIndex]
            guard let byte = UInt8(byteStr, radix: 16) else {
                throw AptosError.parse(.invalidHex("Invalid hex character in: \(byteStr)"))
            }
            data.append(byte)
            index = nextIndex
        }

        return data
    }

    /// Returns true if the string is a valid hex string (with or without prefix).
    public static func isValid(_ hex: String) -> Bool {
        var str = hex
        if str.hasPrefix("0x") || str.hasPrefix("0X") {
            str = String(str.dropFirst(2))
        }
        return !str.isEmpty && str.allSatisfy { $0.isHexDigit }
    }

    /// Strips the "0x" prefix from a hex string if present.
    public static func stripPrefix(_ hex: String) -> String {
        if hex.hasPrefix("0x") || hex.hasPrefix("0X") {
            return String(hex.dropFirst(2))
        }
        return hex
    }
}
