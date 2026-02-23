import Testing
@testable import AptosSDK

@Suite("DerivationPath Tests")
struct DerivationPathTests {
    @Test("Parses apostrophe hardened notation")
    func parseApostropheHardened() throws {
        let path = try DerivationPath("m/44'/637'/0'/0'/0'")
        #expect(path.components.count == 5)
        #expect(path.isFullyHardened)
    }

    @Test("Parses h/H hardened notation")
    func parseHardenedHNotation() throws {
        let lower = try DerivationPath("m/44h/637h/0h/0h/1h")
        let upper = try DerivationPath("m/44H/637H/0H/0H/1H")
        #expect(lower.components == upper.components)
        #expect(lower.isFullyHardened)
    }

    @Test("Mixed hardened notation parses equivalently")
    func mixedNotation() throws {
        let apostrophe = try DerivationPath("m/44'/637'/0'/0'/1'")
        let mixed = try DerivationPath("m/44h/637'/0H/0h/1'")
        #expect(apostrophe.components == mixed.components)
    }
}
