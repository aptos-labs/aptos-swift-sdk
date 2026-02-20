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

## Code Style

### Formatting

The project uses [SwiftFormat](https://github.com/nicklockwood/SwiftFormat) with the configuration in `.swiftformat`. Format your code before committing:

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

### Linting

The project uses [SwiftLint](https://github.com/realm/SwiftLint) with the configuration in `.swiftlint.yml`:

```bash
make lint
```

### Pre-Commit Checklist

Before submitting a PR:

```bash
make ci   # Runs build, test, format-check, lint
```

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

- Throw `AptosError` subtypes (`.parse`, `.crypto`, `.serialization`, `.network`, `.api`, `.transaction`, `.keyless`).
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

### Testing

- Use Swift Testing framework (`import Testing`), not XCTest.
- Group tests in `@Suite("Name")` structs.
- Name tests descriptively: `@Test("AccountAddress from hex roundtrip")`.
- Test BCS roundtrips for all serializable types.
- Test error cases with `#expect(throws:)`.

### Documentation

- All public APIs must have doc comments (`///`).
- Include `///` summary line, then blank line, then details if needed.
- Use `/// - Parameter name:` and `/// - Returns:` for complex methods.
- Include code examples in `///` comments for key entry points.

## Project Structure

```
Sources/AptosSDK/
├── AptosClient.swift          # Unified entry point
├── AptosConfig.swift          # Configuration
├── Account/                   # Account types
├── Advanced/                  # Multi-agent, fee payer, keyless
├── API/                       # Domain-specific API classes
├── BCS/                       # Binary Canonical Serialization
├── Client/                    # HTTP networking
├── Core/                      # Core types and crypto
├── Errors/                    # Error hierarchy
├── Transactions/              # Transaction types and signing
├── Types/                     # API response types
└── Utils/                     # Hashing, caching, helpers
```

## Pull Request Process

1. Create a feature branch from `main`.
2. Make your changes following the code style guidelines.
3. Add tests for new functionality.
4. Run `make ci` to verify everything passes.
5. Open a PR with a clear description of the changes.

## Reporting Issues

Use [GitHub Issues](https://github.com/aptos-labs/aptos-swift-sdk/issues) to report bugs or request features.
