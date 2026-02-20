import Foundation
import XCTest

@testable import AptosSDK

final class SHA3Tests: XCTestCase {

    // MARK: - Utility

    /// Convert a hex string (without 0x prefix) to Data.
    private func hexToData(_ hex: String) -> Data {
        var data = Data(capacity: hex.count / 2)
        var index = hex.startIndex
        while index < hex.endIndex {
            let nextIndex = hex.index(index, offsetBy: 2)
            let byte = UInt8(hex[index..<nextIndex], radix: 16)!
            data.append(byte)
            index = nextIndex
        }
        return data
    }

    /// Convert Data to lowercase hex string (without prefix).
    private func dataToHex(_ data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - NIST Test Vectors

    /// SHA3-256("") = a7ffc6f8bf1ed76651c14756a061d662f580ff4de43b49fa82d80a4b80f8434a
    func testSHA3_256EmptyString() {
        let input = Data()
        let expected = "a7ffc6f8bf1ed76651c14756a061d662f580ff4de43b49fa82d80a4b80f8434a"

        let result = SHA3.sha256(input)
        XCTAssertEqual(result.count, 32, "SHA3-256 output should be 32 bytes")
        XCTAssertEqual(dataToHex(result), expected)
    }

    /// SHA3-256("abc") = 3a985da74fe225b2045c172d6bd390bd855f086e3e9d525b46bfe24511431532
    func testSHA3_256Abc() {
        let input = Data("abc".utf8)
        let expected = "3a985da74fe225b2045c172d6bd390bd855f086e3e9d525b46bfe24511431532"

        let result = SHA3.sha256(input)
        XCTAssertEqual(result.count, 32)
        XCTAssertEqual(dataToHex(result), expected)
    }

    /// SHA3-256("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq")
    /// = 41c0dba2a9d6240849100376a8235e2c82e1b9998a999e21db32dd97496d3376
    func testSHA3_256LongMessage() {
        let input = Data("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq".utf8)
        let expected = "41c0dba2a9d6240849100376a8235e2c82e1b9998a999e21db32dd97496d3376"

        let result = SHA3.sha256(input)
        XCTAssertEqual(result.count, 32)
        XCTAssertEqual(dataToHex(result), expected)
    }

    // MARK: - Additional Test Vectors

    /// Single byte 0x00
    func testSHA3_256SingleZeroByte() {
        let input = Data([0x00])
        let result = SHA3.sha256(input)
        XCTAssertEqual(result.count, 32)
        // Known result for SHA3-256 of single zero byte
        // SHA3-256(0x00) = 5d53469f20fef4f8eab52b88044ede69c77a6a68a60728609fc4a65ff531e7d0
        let expected = "5d53469f20fef4f8eab52b88044ede69c77a6a68a60728609fc4a65ff531e7d0"
        XCTAssertEqual(dataToHex(result), expected)
    }

    // MARK: - Output Properties

    func testSHA3_256OutputIsAlways32Bytes() {
        // Test various input sizes
        let inputs: [Data] = [
            Data(),
            Data([0x01]),
            Data(repeating: 0xAB, count: 100),
            Data(repeating: 0xFF, count: 1000),
            Data(repeating: 0x42, count: 136),  // Exactly one block for SHA3-256
            Data(repeating: 0x42, count: 137),   // Slightly more than one block
        ]

        for input in inputs {
            let result = SHA3.sha256(input)
            XCTAssertEqual(result.count, 32, "SHA3-256 output should always be 32 bytes for input of size \(input.count)")
        }
    }

    func testSHA3_256DeterministicOutput() {
        let input = Data("deterministic test".utf8)
        let result1 = SHA3.sha256(input)
        let result2 = SHA3.sha256(input)
        XCTAssertEqual(result1, result2, "Same input should always produce same output")
    }

    func testSHA3_256DifferentInputsDifferentOutputs() {
        let input1 = Data("hello".utf8)
        let input2 = Data("world".utf8)
        let result1 = SHA3.sha256(input1)
        let result2 = SHA3.sha256(input2)
        XCTAssertNotEqual(result1, result2, "Different inputs should produce different outputs")
    }

    // MARK: - Boundary Conditions

    func testSHA3_256ExactlyOneBlockInput() {
        // SHA3-256 rate = 136 bytes. Input of exactly 136 bytes forces an exact block boundary.
        let input = Data(repeating: 0xAA, count: 136)
        let result = SHA3.sha256(input)
        XCTAssertEqual(result.count, 32)
    }

    func testSHA3_256MultiBlockInput() {
        // Multiple blocks
        let input = Data(repeating: 0xBB, count: 500)
        let result = SHA3.sha256(input)
        XCTAssertEqual(result.count, 32)
    }

    // MARK: - sha3_256 Convenience Function

    func testSha3_256ConvenienceFunction() {
        // The global sha3_256() function should produce the same result as SHA3.sha256()
        let input = Data("abc".utf8)
        let directResult = SHA3.sha256(input)
        let convenienceResult = sha3_256(input)
        XCTAssertEqual(directResult, convenienceResult)
    }

    // MARK: - Aptos-specific Usage

    func testSHA3_256WithDomainSeparator() {
        // Aptos uses SHA3-256 for things like hashing "APTOS::RawTransaction"
        let salt = "APTOS::RawTransaction"
        let saltHash = SHA3.sha256(Data(salt.utf8))
        XCTAssertEqual(saltHash.count, 32)
        // Just ensure it produces consistent output
        let saltHash2 = SHA3.sha256(Data(salt.utf8))
        XCTAssertEqual(saltHash, saltHash2)
    }
}
