import Foundation

// MARK: - TestVectorLoader

/// Utility for loading test vector JSON files from the test bundle.
enum TestVectorLoader {
    /// Loads and decodes a JSON file from the TestVectors resource directory.
    static func load<T: Decodable>(_ filename: String) throws -> T {
        guard let url = Bundle.module.url(forResource: filename, withExtension: "json", subdirectory: "TestVectors")
        else {
            throw TestVectorError.fileNotFound(filename)
        }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }

    /// Loads raw JSON as a dictionary.
    static func loadJSON(_ filename: String) throws -> [String: Any] {
        guard let url = Bundle.module.url(forResource: filename, withExtension: "json", subdirectory: "TestVectors")
        else {
            throw TestVectorError.fileNotFound(filename)
        }
        let data = try Data(contentsOf: url)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw TestVectorError.invalidFormat(filename)
        }
        return json
    }

    enum TestVectorError: Error {
        case fileNotFound(String)
        case invalidFormat(String)
    }
}

/// Converts a hex string (with or without "0x" prefix) to Data.
func hexToData(_ hex: String) -> Data {
    let cleaned = hex.hasPrefix("0x") ? String(hex.dropFirst(2)) : hex
    guard !cleaned.isEmpty else { return Data() }
    var data = Data()
    var index = cleaned.startIndex
    while index < cleaned.endIndex {
        let nextIndex = cleaned.index(index, offsetBy: 2, limitedBy: cleaned.endIndex) ?? cleaned.endIndex
        if let byte = UInt8(cleaned[index ..< nextIndex], radix: 16) {
            data.append(byte)
        }
        index = nextIndex
    }
    return data
}

/// Converts Data to a lowercase hex string without prefix.
func dataToHex(_ data: Data) -> String {
    data.map { String(format: "%02x", $0) }.joined()
}
