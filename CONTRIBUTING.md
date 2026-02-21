# Contributing to Aptos Swift SDK

## Development Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/aptos-labs/aptos-swift-sdk.git
   cd aptos-swift-sdk
   ```

2. Install development tools:
   ```bash
   brew install swiftformat swiftlint
   ```

3. Build and test:
   ```bash
   swift build
   swift test
   ```

4. Verify everything passes:
   ```bash
   make ci   # Runs build, test, format-check, lint
   ```

## Code Style

### Formatting

The project uses [SwiftFormat](https://github.com/nicklockwood/SwiftFormat) with the configuration in `.swiftformat`. **Always format your code before committing:**

```bash
make format
```

Key formatting rules:
- 4-space indentation (no tabs)
- 120-character line length maximum
- Sorted imports with `@testable` at the bottom
- Trailing commas in multi-line collections
- Remove redundant `self`, `return`, `init`, `Void`
- K&R brace style (`} else {` on same line)
- `guard else` on next line
- Arguments/parameters wrap before-first when exceeding line length
- Balanced closing parentheses

The full configuration is in `.swiftformat`. Do not override these settings in individual files.

### Linting

The project uses [SwiftLint](https://github.com/realm/SwiftLint) with the configuration in `.swiftlint.yml`:

```bash
make lint
```

Key rules:
- **No force unwrapping** (`!`) — use `guard let` or `if let` instead
- **Line length**: 120 warning, 200 error (comments and URLs are exempt)
- **Function body length**: 60 lines warning, 100 error
- **Cyclomatic complexity**: 15 warning, 25 error
- **Identifier names**: minimum 2 characters (loop vars `i`, `j`, `x`, `y` etc. are exempted)
- **50+ opt-in rules** for code quality (see `.swiftlint.yml` for the full list)

When a lint rule is unavoidable (e.g., a 2048-element array for the BIP-39 wordlist), use targeted inline disable comments:

```swift
// swiftlint:disable:next line_length
let longLine = "..."

// swiftlint:disable file_length type_body_length
// ... entire file ...
```

Never disable rules globally — always use the narrowest possible scope.

### Pre-Commit Checklist

Before submitting a PR, always run the full CI pipeline:

```bash
make ci   # Runs: build → test → format-check → lint
```

This is the same pipeline that runs in GitHub Actions. A PR will not be merged if any of these checks fail.

## Coding Conventions

### Type Design

- **Prefer value types** (structs, enums) over classes.
- **All public types must be `Sendable`**. The SDK targets Swift 6.0 strict concurrency.
- **Use `~Copyable`** for types that manage unique resources (e.g., BCS Serializer).
- **Use enums for variants** (e.g., `AnyPublicKey`, `TransactionAuthenticator`), not protocols with type erasure.

### Naming

- Follow Apple's [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/).
- Types: `UpperCamelCase` (`AccountAddress`, `Ed25519PublicKey`)
- Functions/properties: `lowerCamelCase` (`fromHex`, `signingMessage`)
- Constants: `lowerCamelCase` (`defaultMaxGasAmount`)
- Abbreviations: Treat as words (`bcsToBytes`, not `BCSToBytes`; `Url`, not `URL` in compound names)
- Test suites: `@Suite("Descriptive Name")` with `@Test("what it tests")` per test

### Error Handling

- Throw `AptosError` subtypes for domain-specific errors:
  - `.parse(...)` — hex, address, type tag, mnemonic parsing
  - `.crypto(...)` — key length, signature length, derivation failures
  - `.serialization(...)` — BCS encoding/decoding, depth limits
  - `.network(...)` — HTTP errors, timeouts, URL issues
  - `.api(...)` — resource not found, simulation failures
  - `.transaction(...)` — build/submit/wait failures
  - `.keyless(...)` — pepper/prover service failures
- Use top-level error cases for HTTP-specific status codes:
  - `.unauthorized(...)` — HTTP 401
  - `.rateLimited(...)` — HTTP 429
  - `.internalError(...)` — HTTP 5xx
- Validate inputs at construction time (fail-fast).
- Include descriptive error messages.

### BCS Serialization

Every on-chain type must conform to `BCSSerializable` and/or `BCSDeserializable`:

```swift
extension MyType: BCSSerializable, BCSDeserializable {
    func serialize(to serializer: inout Serializer) throws {
        // Serialize fields in order
    }

    static func deserialize(from deserializer: inout Deserializer) throws -> MyType {
        // Deserialize fields in same order
    }
}
```

The serializer and deserializer enforce a maximum nesting depth of 128 to prevent stack overflow from malicious inputs.

### Testing

- Use Swift Testing framework (`import Testing`), not XCTest.
- Group tests in `@Suite("Name")` structs.
- Name tests descriptively: `@Test("AccountAddress from hex roundtrip")`.
- Test BCS roundtrips for all serializable types.
- Test error cases with `#expect(throws:)`.
- Use parameterized tests with `arguments:` for vector-style test cases.
- For deterministic test vectors, use the JSON files in `Tests/AptosSDKTests/TestVectors/` and the `TestVectorLoader` utility.

### Documentation

- All public APIs must have doc comments (`///`).
- Include `///` summary line, then blank line, then details if needed.
- Use `/// - Parameter name:` and `/// - Returns:` for complex methods.
- Include code examples in `///` comments for key entry points.

### C Code (CTweetNaCl)

The `Sources/CTweetNaCl/` directory contains an embedded C implementation of Ed25519 (based on TweetNaCl) for deterministic signing. When modifying this code:

- Keep functions in dependency order (callees before callers) since C requires forward declaration.
- The public API is defined in `include/tweetnacl.h` — only expose what Swift needs.
- Use `static` for all internal helper functions.
- Do not add external C dependencies — this must remain self-contained.

## Project Structure

```
aptos-swift-sdk/
├── Package.swift
├── Makefile                          # Build, test, format, lint targets
├── .swiftformat                      # SwiftFormat configuration
├── .swiftlint.yml                    # SwiftLint configuration
├── .github/workflows/ci.yml         # GitHub Actions CI
├── docs/
│   └── swift-DESIGN.md              # Architecture design document
├── Sources/
│   ├── CTweetNaCl/                   # Embedded C library
│   │   ├── include/tweetnacl.h       # Public header (Ed25519 API)
│   │   └── tweetnacl.c              # Ed25519 deterministic signing
│   └── AptosSDK/
│       ├── AptosClient.swift         # Unified entry point
│       ├── AptosConfig.swift         # Configuration + RetryConfig
│       ├── Account/
│       │   ├── Account.swift         # AptosAccount protocol + publicKeyBytes
│       │   ├── Ed25519Account.swift  # Legacy Ed25519 + fromMnemonic()
│       │   ├── SingleKeyAccount.swift # Unified single-key + AnyPrivateKey
│       │   └── MultiKeyAccount.swift # M-of-N multi-sig
│       ├── Advanced/
│       │   ├── KeylessAccount.swift  # OIDC-based keyless
│       │   ├── EphemeralKeyPair.swift # Short-lived keys
│       │   ├── MultiAgent.swift      # Multi-agent flows
│       │   └── FeePayer.swift        # Fee payer flows
│       ├── API/
│       │   ├── GeneralAPI.swift      # Ledger info, gas, blocks
│       │   ├── AccountAPI.swift      # Account resources
│       │   ├── TransactionAPI.swift  # Submit, wait, simulate
│       │   ├── ViewAPI.swift         # View function calls
│       │   ├── FaucetAPI.swift       # Testnet faucet + createAndFundAccount()
│       │   ├── CoinAPI.swift         # APT operations
│       │   ├── DigitalAssetAPI.swift # NFT operations
│       │   ├── FungibleAssetAPI.swift # FA operations
│       │   ├── ANSAPI.swift          # Name service
│       │   ├── StakingAPI.swift      # Staking/delegation
│       │   ├── ObjectAPI.swift       # Object queries
│       │   ├── TableAPI.swift        # Table queries
│       │   ├── EventAPI.swift        # Event queries
│       │   ├── KeylessAPI.swift      # Keyless auth
│       │   └── IndexerClient.swift   # GraphQL queries
│       ├── BCS/
│       │   ├── Serializer.swift      # BCS encoder (~Copyable, depth-tracked)
│       │   ├── Deserializer.swift    # BCS decoder (~Copyable, depth-tracked)
│       │   └── BCSSerializable.swift # Protocols + helpers
│       ├── Client/
│       │   └── HTTPClient.swift      # Actor-based HTTP with retry
│       ├── Core/
│       │   ├── AccountAddress.swift  # 32-byte address
│       │   ├── Hex.swift             # Hex utilities
│       │   ├── TypeTag.swift         # Move type tags
│       │   └── Crypto/
│       │       ├── Hashing.swift     # SHA3/SHA2, domain separation
│       │       ├── Ed25519.swift     # Ed25519 (CTweetNaCl + CryptoKit)
│       │       ├── Secp256k1.swift   # P256K secp256k1
│       │       ├── Secp256r1.swift   # CryptoKit P-256
│       │       ├── AuthenticationKey.swift # Key → address derivation
│       │       ├── AnyPublicKey.swift # Type-erased keys
│       │       ├── AnySignature.swift # Type-erased sigs
│       │       ├── MultiKey.swift    # Multi-key crypto
│       │       ├── KeylessPublicKey.swift # Keyless public key
│       │       ├── PrivateKey.swift   # AIP-80 utilities
│       │       ├── Mnemonic.swift    # BIP-39 mnemonic generation/validation/seed
│       │       ├── HDKey.swift       # SLIP-0010 + BIP-32 key derivation
│       │       ├── DerivationPath.swift # BIP-44 path parsing
│       │       └── BIP39Wordlist.swift # 2048-word English wordlist
│       ├── Errors/
│       │   └── AptosError.swift      # Error hierarchy
│       ├── Transactions/
│       │   ├── RawTransaction.swift  # Raw + Signed + ChainId
│       │   ├── TransactionPayload.swift # Payloads + EntryFunction
│       │   ├── TransactionAuthenticator.swift # Authenticators
│       │   ├── TransactionBuilder.swift # Builder + wrappers
│       │   └── Signer.swift          # Signing utilities
│       ├── Types/
│       │   ├── APITypes.swift        # REST response types
│       │   └── Network.swift         # Network definitions
│       └── Utils/
│           ├── Cache.swift           # Actor LRU cache
│           ├── Constants.swift       # SDK constants
│           ├── Endpoints.swift       # URL resolution
│           ├── Extensions.swift      # Data/String helpers
│           └── SHA3.swift            # Keccak-f[1600]
└── Tests/AptosSDKTests/
    ├── TestVectorLoader.swift        # JSON loader + hex helpers
    ├── TestVectors/                  # Spec test vector JSON files
    │   ├── addresses.json
    │   ├── bcs.json
    │   ├── signatures.json
    │   ├── type-tags.json
    │   ├── transactions.json
    │   ├── mnemonics.json
    │   └── multi-sig.json
    ├── AddressVectorTests.swift      # Address parsing/constant vectors
    ├── BCSVectorTests.swift          # BCS serialization vectors
    ├── SignatureVectorTests.swift     # Crypto/signing vectors
    ├── TypeTagVectorTests.swift      # Move type parsing vectors
    ├── TransactionVectorTests.swift  # Transaction encoding vectors
    ├── MnemonicVectorTests.swift     # BIP-39/SLIP-0010 vectors
    ├── MultiSigVectorTests.swift     # Multi-sig vectors
    ├── BCS/
    │   ├── SerializerTests.swift
    │   └── DeserializerTests.swift
    ├── Core/
    │   ├── AccountAddressTests.swift
    │   ├── TypeTagTests.swift
    │   ├── Ed25519Tests.swift
    │   ├── Secp256k1Tests.swift
    │   ├── Secp256r1Tests.swift
    │   ├── HashingTests.swift
    │   └── AuthenticationKeyTests.swift
    ├── Account/
    │   └── AccountTests.swift
    ├── Transactions/
    │   └── TransactionTests.swift
    └── Advanced/
        ├── MultiAgentTests.swift
        ├── FeePayerTests.swift
        └── KeylessTests.swift
```

## Pull Request Process

1. Create a feature branch from `main`.
2. Make your changes following the code style guidelines.
3. Add tests for new functionality.
4. Run `make ci` to verify everything passes.
5. Open a PR with a clear description of the changes.

## Reporting Issues

Use [GitHub Issues](https://github.com/aptos-labs/aptos-swift-sdk/issues) to report bugs or request features.
