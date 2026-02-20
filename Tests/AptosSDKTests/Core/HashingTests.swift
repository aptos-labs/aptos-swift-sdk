import Testing
import Foundation
@testable import AptosSDK

@Suite("Hashing Tests")
struct HashingTests {
    @Test("SHA3-256 empty input")
    func sha3EmptyInput() throws {
        let hash = SHA3.sha256([])
        #expect(hash.count == 32)
        // Known SHA3-256("") = a7ffc6f8bf1ed76651c14756a061d662f580ff4de43b49fa82d80a4b80f8434a
        let expected = "a7ffc6f8bf1ed76651c14756a061d662f580ff4de43b49fa82d80a4b80f8434a"
        #expect(Hex.encodeWithoutPrefix(hash) == expected)
    }

    @Test("SHA3-256 known test vector")
    func sha3KnownVector() throws {
        let input = Array("abc".utf8)
        let hash = SHA3.sha256(input)
        // Known SHA3-256("abc") = 3a985da74fe225b2045c172d6bd390bd855f086e3e9d525b46bfe24511431532
        let expected = "3a985da74fe225b2045c172d6bd390bd855f086e3e9d525b46bfe24511431532"
        #expect(Hex.encodeWithoutPrefix(hash) == expected)
    }

    @Test("SHA2-256 via CryptoKit")
    func sha2_256() throws {
        let data = Data("test".utf8)
        let hash = AptosHashing.sha2_256(data)
        #expect(hash.count == 32)
    }

    @Test("Domain-separated hash")
    func domainSeparatedHash() throws {
        let hash = AptosHashing.hashWithDomainSeparation(domain: "APTOS::test", data: Data("hello".utf8))
        #expect(hash.count == 32)
    }

    @Test("Signing prefix")
    func signingPrefix() throws {
        let prefix = AptosHashing.signingPrefix(AptosDomain.rawTransaction)
        #expect(prefix.count == 32)
    }
}
