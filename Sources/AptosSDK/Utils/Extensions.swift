import Foundation

extension Data {
    /// Returns a hex string representation of this data with "0x" prefix.
    public var hexString: String {
        Hex.encode(self)
    }

    /// Creates Data from a hex string.
    public static func fromHex(_ hex: String) throws -> Data {
        try Hex.decode(hex)
    }
}

extension String {
    /// Returns true if this string has a "0x" or "0X" prefix.
    public var hasHexPrefix: Bool {
        hasPrefix("0x") || hasPrefix("0X")
    }
}
