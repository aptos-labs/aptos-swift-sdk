# Aptos Swift SDK - Design Document

**Target Language:** Swift 6.0+
**Platforms:** iOS 17+ / macOS 14+
**Package Manager:** Swift Package Manager (SPM)
**License:** Apache-2.0

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Package Structure](#2-package-structure)
3. [Module Design](#3-module-design)
4. [Type System Mapping](#4-type-system-mapping)
5. [BCS Serialization](#5-bcs-serialization)
6. [Cryptographic Layer](#6-cryptographic-layer)
7. [Account System](#7-account-system)
8. [Transaction System](#8-transaction-system)
9. [HTTP Client Layer](#9-http-client-layer)
10. [GraphQL / Indexer Layer](#10-graphql--indexer-layer)
11. [API Surface](#11-api-surface)
12. [Keyless Authentication](#12-keyless-authentication)
13. [Account Abstraction](#13-account-abstraction)
14. [Error Handling](#14-error-handling)
15. [Concurrency Model](#15-concurrency-model)
16. [Differences from TypeScript SDK](#16-differences-from-typescript-sdk)
17. [Performance Considerations](#17-performance-considerations)
18. [Dependencies](#18-dependencies)
19. [Testing Strategy](#19-testing-strategy)
20. [Formatting & Linting](#20-formatting--linting)
21. [Implementation Plan](#21-implementation-plan)

---

## 1. Architecture Overview

### 1.1 Layer Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                      AptosClient (Main Entry)                    │
│  ┌──────────┬──────────┬──────────┬──────────┬────────────────┐ │
│  │ account  │  coin    │  ans     │ keyless  │ object         │ │
│  │ digital  │ fungible │ staking  │ general  │ table          │ │
│  │ Asset    │ Asset    │          │          │ abstraction    │ │
│  │ faucet   │          │transaction                          │ │
│  └──────────┴──────────┴──────────┴──────────┴────────────────┘ │
├─────────────────────────────────────────────────────────────────┤
│                     Domain API Layer                              │
│  (Protocols + concrete implementations per domain)               │
├─────────────────────────────────────────────────────────────────┤
│                  Transaction Builder Layer                        │
│  (Payload construction, signing, authenticators)                 │
├─────────────────────────────────────────────────────────────────┤
│                     HTTP Client Layer                             │
│  (URLSession + async/await, pagination, error mapping)           │
├──────────────────────────┬──────────────────────────────────────┤
│    Core / Crypto Layer   │        BCS Layer                      │
│  (Keys, signatures,      │  (Serializer, Deserializer,          │
│   addresses, hashing)    │   Serializable protocol)             │
└──────────────────────────┴──────────────────────────────────────┘
```

### 1.2 Composition Pattern

The `AptosClient` class uses composition, matching the TypeScript SDK pattern but using Swift idioms:

```swift
public final class AptosClient: Sendable {
    public let config: AptosConfig
    public let account: AccountAPI
    public let abstraction: AccountAbstractionAPI
    public let ans: ANSAPI
    public let coin: CoinAPI
    public let digitalAsset: DigitalAssetAPI
    public let faucet: FaucetAPI
    public let fungibleAsset: FungibleAssetAPI
    public let general: GeneralAPI
    public let keyless: KeylessAPI
    public let object: ObjectAPI
    public let staking: StakingAPI
    public let table: TableAPI
    public let transaction: TransactionAPI
}
```

Each domain API is a `struct` conforming to `Sendable`, receiving `AptosConfig` at initialization.

---

## 2. Package Structure

```
aptos-swift-sdk/
├── Package.swift
├── Sources/
│   └── AptosSDK/
│       ├── AptosClient.swift              # Main entry point
│       ├── AptosConfig.swift              # Configuration
│       ├── BCS/
│       │   ├── Serializer.swift           # BCS serialization
│       │   ├── Deserializer.swift         # BCS deserialization
│       │   └── Serializable.swift         # Serializable protocol
│       ├── Core/
│       │   ├── Crypto/
│       │   │   ├── Ed25519.swift          # Ed25519 key types
│       │   │   ├── Secp256k1.swift        # Secp256k1 key types
│       │   │   ├── Secp256r1.swift        # Secp256r1 (P-256) key types
│       │   │   ├── MultiKey.swift         # Multi-key types
│       │   │   ├── KeylessPublicKey.swift  # Keyless key types
│       │   │   ├── AnyPublicKey.swift     # AnyPublicKey enum wrapper
│       │   │   ├── AnySignature.swift     # AnySignature enum wrapper
│       │   │   └── PrivateKey.swift       # AIP-80 formatting
│       │   ├── AccountAddress.swift       # 32-byte account address
│       │   ├── AuthenticationKey.swift    # Auth key derivation
│       │   ├── Hex.swift                  # Hex encoding/decoding
│       │   └── TypeTag.swift             # Move type tags
│       ├── Account/
│       │   ├── Account.swift             # Account protocol
│       │   ├── Ed25519Account.swift      # Ed25519 account
│       │   ├── SingleKeyAccount.swift    # Single key account
│       │   ├── MultiKeyAccount.swift     # Multi-key account
│       │   ├── MultiEd25519Account.swift # Legacy multi-Ed25519
│       │   ├── KeylessAccount.swift      # Keyless account
│       │   ├── FederatedKeylessAccount.swift
│       │   ├── AbstractedAccount.swift   # Account abstraction
│       │   ├── DerivableAbstractedAccount.swift
│       │   └── AccountUtils.swift        # Serialization utilities
│       ├── Transactions/
│       │   ├── Types.swift               # Transaction type definitions
│       │   ├── Builder.swift             # Transaction builder
│       │   ├── Signer.swift              # Transaction signing
│       │   ├── Authenticator.swift       # Authenticator types
│       │   ├── Payload.swift             # Payload types
│       │   ├── TransactionWorker.swift   # Batch processing
│       │   └── AccountSequenceNumber.swift
│       ├── Client/
│       │   ├── AptosHTTPClient.swift     # URLSession wrapper
│       │   ├── AptosRequest.swift        # Request types
│       │   ├── AptosResponse.swift       # Response types
│       │   ├── Pagination.swift          # Cursor/offset pagination
│       │   └── MIMEType.swift            # Content types
│       ├── API/
│       │   ├── AccountAPI.swift
│       │   ├── AccountAbstractionAPI.swift
│       │   ├── ANSAPI.swift
│       │   ├── CoinAPI.swift
│       │   ├── DigitalAssetAPI.swift
│       │   ├── FaucetAPI.swift
│       │   ├── FungibleAssetAPI.swift
│       │   ├── GeneralAPI.swift
│       │   ├── KeylessAPI.swift
│       │   ├── ObjectAPI.swift
│       │   ├── StakingAPI.swift
│       │   ├── TableAPI.swift
│       │   └── TransactionAPI.swift
│       ├── Indexer/
│       │   ├── Generated/               # Apollo-generated types
│       │   ├── Queries/                  # .graphql query files
│       │   └── IndexerClient.swift       # GraphQL client wrapper
│       ├── Types/
│       │   ├── Network.swift             # Network enum
│       │   ├── APITypes.swift            # API response types
│       │   ├── MoveTypes.swift           # Move type representations
│       │   ├── PropertyType.swift        # Digital asset property types & serialization
│       │   ├── TransactionTypes.swift    # Transaction response types
│       │   └── IndexerTypes.swift        # Indexer response types
│       ├── Errors/
│       │   ├── AptosError.swift          # Base error types
│       │   ├── AptosAPIError.swift       # HTTP API errors
│       │   ├── TransactionError.swift    # Transaction-specific errors
│       │   └── KeylessError.swift        # Keyless auth errors
│       └── Utils/
│           ├── Constants.swift           # SDK constants
│           ├── Endpoints.swift           # Network endpoint URLs
│           ├── Cache.swift               # LRU cache with TTL
│           └── Extensions.swift          # Data/String extensions
├── Tests/
│   └── AptosSDKTests/
│       ├── BCS/
│       │   ├── SerializerTests.swift
│       │   └── DeserializerTests.swift
│       ├── Core/
│       │   ├── Ed25519Tests.swift
│       │   ├── Secp256k1Tests.swift
│       │   ├── Secp256r1Tests.swift
│       │   ├── AccountAddressTests.swift
│       │   └── AuthenticationKeyTests.swift
│       ├── Account/
│       │   ├── AccountTests.swift
│       │   └── AccountSerializationTests.swift
│       ├── Transactions/
│       │   ├── BuilderTests.swift
│       │   ├── SignerTests.swift
│       │   └── AuthenticatorTests.swift
│       ├── Client/
│       │   ├── HTTPClientTests.swift
│       │   └── PaginationTests.swift
│       ├── API/
│       │   └── ... (integration tests per API domain)
│       └── E2E/
│           ├── TransactionE2ETests.swift
│           ├── AccountE2ETests.swift
│           └── KeylessE2ETests.swift
└── docs/
    ├── SPEC.md
    └── swift-DESIGN.md
```

### 2.1 SPM Target Structure

```swift
// Package.swift
let package = Package(
    name: "AptosSDK",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "AptosSDK", targets: ["AptosSDK"]),
    ],
    dependencies: [
        // Crypto
        .package(url: "https://github.com/GigaBitcoin/secp256k1.swift", from: "0.18.0"),
        // GraphQL
        .package(url: "https://github.com/apollographql/apollo-ios", from: "1.15.0"),
        // BIP-39/32 key derivation
        .package(url: "https://github.com/nicklama/Bip39", from: "1.0.0"),
        // BigInt for u128/u256
        .package(url: "https://github.com/attaswift/BigInt", from: "5.4.0"),
    ],
    targets: [
        .target(
            name: "AptosSDK",
            dependencies: [
                .product(name: "secp256k1", package: "secp256k1.swift"),
                .product(name: "Apollo", package: "apollo-ios"),
                .product(name: "Bip39", package: "Bip39"),
                .product(name: "BigInt", package: "BigInt"),
            ]
        ),
        .testTarget(
            name: "AptosSDKTests",
            dependencies: ["AptosSDK"]
        ),
    ]
)
```

---

## 3. Module Design

### 3.1 Module Dependency Diagram

```
                    ┌─────────────────┐
                    │   AptosClient    │
                    └────────┬────────┘
                             │
              ┌──────────────┼──────────────┐
              │              │              │
     ┌────────▼───────┐ ┌───▼───────┐ ┌───▼────────────┐
     │   API Layer     │ │ Indexer   │ │ Transactions   │
     │ (domain APIs)   │ │ (Apollo)  │ │ (builder/sign) │
     └────────┬────┬───┘ └───┬───────┘ └────┬───────────┘
              │    │         │               │
     ┌────────▼────┼─────────▼───────────────┤
     │        HTTP Client (URLSession)       │
     └────────┬──────────────────────────────┘
              │
     ┌────────▼───────────────────────────────┐
     │              Core Layer                 │
     │  ┌──────────┐  ┌────────┐  ┌─────────┐│
     │  │  Crypto   │  │  BCS   │  │  Types  ││
     │  └──────────┘  └────────┘  └─────────┘│
     └─────────────────────────────────────────┘
```

### 3.2 Module Responsibilities

| Module | Responsibility |
|--------|---------------|
| `BCS/` | Binary Canonical Serialization (serialize/deserialize all on-chain types) |
| `Core/Crypto/` | Key generation, signing, verification, hashing |
| `Core/` | AccountAddress, AuthenticationKey, Hex, TypeTag |
| `Account/` | Account protocol and concrete account implementations |
| `Transactions/` | Transaction building, signing, payload construction, batch management |
| `Client/` | HTTP client, request/response types, pagination |
| `API/` | High-level domain APIs (account, coin, NFT, etc.) |
| `Indexer/` | Apollo GraphQL client, generated types, query definitions |
| `Types/` | Shared type definitions, enums, response models, PropertyType/PropertyValue for digital assets |
| `Errors/` | Error types and classification |
| `Utils/` | Constants, endpoints, caching, extensions |

---

## 4. Type System Mapping

### 4.1 TypeScript to Swift Type Mapping

| TypeScript | Swift | Notes |
|-----------|-------|-------|
| `class` (abstract) | `protocol` | Swift protocols for abstract types |
| `class` (concrete) | `final class` / `struct` | `struct` for value types, `class` for identity/reference semantics |
| `interface` | `struct` conforming to `Codable` | For data transfer objects |
| `enum` | `enum` | Swift enums with associated values for variants |
| `bigint` | `UInt64` / `BigUInt` | `UInt64` for u64, `BigUInt` for u128/u256 |
| `number` | `UInt8/16/32` or `Int8/16/32` | Sized integer types |
| `string` | `String` | Direct mapping |
| `boolean` | `Bool` | Direct mapping |
| `Uint8Array` | `Data` | Foundation `Data` for byte arrays |
| `Array<T>` | `[T]` | Swift arrays |
| `Record<K,V>` | `[K: V]` | Swift dictionaries |
| `T \| undefined` | `T?` | Swift optionals |
| `Promise<T>` | `async throws -> T` | Swift concurrency |
| `EventEmitter` | `AsyncStream` / actor | Swift structured concurrency patterns |

### 4.2 Move Type to Swift Mapping

| Move Type | Swift Type | BCS Encoding |
|-----------|-----------|-------------|
| `bool` | `Bool` | 1 byte |
| `u8` | `UInt8` | 1 byte |
| `u16` | `UInt16` | 2 bytes LE |
| `u32` | `UInt32` | 4 bytes LE |
| `u64` | `UInt64` | 8 bytes LE |
| `u128` | `BigUInt` | 16 bytes LE |
| `u256` | `BigUInt` | 32 bytes LE |
| `i8` | `Int8` | 1 byte (two's complement) |
| `i16` | `Int16` | 2 bytes LE |
| `i32` | `Int32` | 4 bytes LE |
| `i64` | `Int64` | 8 bytes LE |
| `i128` | `BigInt` | 16 bytes LE |
| `i256` | `BigInt` | 32 bytes LE |
| `address` | `AccountAddress` | 32 bytes |
| `String` | `String` | ULEB128 len + UTF-8 |
| `vector<T>` | `[T]` | ULEB128 count + elements |
| `Option<T>` | `T?` | 0x00 / 0x01 + value |

### 4.3 HexInput Equivalent

```swift
/// Represents any input that can be converted to raw bytes.
public protocol HexInput {
    var data: Data { get }
}

extension Data: HexInput {
    public var data: Data { self }
}

extension String: HexInput {
    public var data: Data { Hex.decode(self) }
}

extension AccountAddress: HexInput {
    public var data: Data { self.rawData }
}
```

### 4.4 AnyNumber Equivalent

```swift
/// Protocol for numeric types used in transaction options.
public protocol AnyNumber {
    var toUInt64: UInt64 { get }
}

extension Int: AnyNumber { ... }
extension UInt64: AnyNumber { ... }
extension BigUInt: AnyNumber { ... }
```

---

## 5. BCS Serialization

### 5.1 Serializable Protocol

```swift
/// All BCS-serializable types conform to this protocol.
public protocol Serializable {
    func serialize(to serializer: inout Serializer)
}

extension Serializable {
    /// Serialize to raw bytes.
    public func bcsToBytes() -> Data {
        var serializer = Serializer()
        serialize(to: &serializer)
        return serializer.output()
    }

    /// Serialize to Hex.
    public func bcsToHex() -> Hex {
        Hex(data: bcsToBytes())
    }
}
```

### 5.2 Deserializable Protocol

```swift
/// All BCS-deserializable types conform to this protocol.
public protocol Deserializable {
    static func deserialize(from deserializer: inout Deserializer) throws -> Self
}
```

### 5.3 Serializer

```swift
/// BCS binary serializer with growing buffer.
public struct Serializer: ~Copyable {
    private var buffer: Data
    private var offset: Int

    public init(capacity: Int = 64) { ... }

    public mutating func serializeBool(_ value: Bool) { ... }
    public mutating func serializeU8(_ value: UInt8) { ... }
    public mutating func serializeU16(_ value: UInt16) { ... }
    public mutating func serializeU32(_ value: UInt32) { ... }
    public mutating func serializeU64(_ value: UInt64) { ... }
    public mutating func serializeU128(_ value: BigUInt) { ... }
    public mutating func serializeU256(_ value: BigUInt) { ... }
    public mutating func serializeI8(_ value: Int8) { ... }
    public mutating func serializeI16(_ value: Int16) { ... }
    public mutating func serializeI32(_ value: Int32) { ... }
    public mutating func serializeI64(_ value: Int64) { ... }
    public mutating func serializeI128(_ value: BigInt) { ... }
    public mutating func serializeI256(_ value: BigInt) { ... }
    public mutating func serializeStr(_ value: String) { ... }
    public mutating func serializeBytes(_ value: Data) { ... }
    public mutating func serializeFixedBytes(_ value: Data) { ... }
    public mutating func serializeU32AsUleb128(_ value: UInt32) { ... }
    public mutating func serializeVector<T: Serializable>(_ values: [T]) { ... }
    public mutating func serializeOption<T: Serializable>(_ value: T?) { ... }

    public consuming func output() -> Data { ... }
}
```

**Design Decision:** `Serializer` is `~Copyable` (non-copyable type, Swift 5.9+) to prevent accidental duplication of the internal buffer. The `output()` method is `consuming` — it transfers ownership of the buffer and invalidates the serializer, ensuring zero-copy extraction.

**Buffer growth:** Same strategy as TypeScript — `max(current * 1.5, current + needed)` with 256-byte minimum increment.

### 5.4 Deserializer

```swift
/// BCS binary deserializer.
public struct Deserializer {
    private let data: Data
    private var offset: Int

    public init(data: Data) { ... }

    public mutating func deserializeBool() throws -> Bool { ... }
    public mutating func deserializeU8() throws -> UInt8 { ... }
    // ... mirrors Serializer methods

    public func remaining() -> Int { ... }
    public func assertFinished() throws { ... }
}
```

**Security:** 10MB max length for `deserializeBytes()`, returns copies (not slices) of byte arrays.

### 5.5 Differences from TypeScript

| Aspect | TypeScript | Swift |
|--------|-----------|-------|
| Buffer type | `Uint8Array` | `Data` (Foundation) |
| Object pooling | 8-instance pool | Not needed — `Serializer` is stack-allocated as `~Copyable` |
| Growth | Dynamic `ArrayBuffer` | `Data` with `reserveCapacity` |
| Endianness | Manual LE writes | `withUnsafeBytes` + LE conversion via `.littleEndian` |
| BigInt | Native `BigInt` | `BigUInt`/`BigInt` from attaswift/BigInt |

---

## 6. Cryptographic Layer

### 6.1 Library Mapping

| Algorithm | TypeScript Library | Swift Library |
|-----------|-------------------|---------------|
| Ed25519 | `@noble/curves` | `CryptoKit.Curve25519` |
| Secp256k1 | `@noble/curves` | `secp256k1.swift` (GigaBitcoin) |
| Secp256r1 (P-256) | `@noble/curves` | `CryptoKit.P256` |
| SHA3-256 | `@noble/hashes` | `CryptoKit.SHA256` → actually need SHA3, use `CommonCrypto` or dedicated lib |
| SHA-256 | `@noble/hashes` | `CryptoKit.SHA256` |
| Poseidon | `poseidon-lite` | Custom implementation (for keyless nonce) |
| BIP-39 | `@scure/bip39` | `Bip39` |
| BIP-32 | `@scure/bip32` | Custom SLIP-0010 derivation |

**Important:** CryptoKit provides `SHA256` (SHA-2), not `SHA3-256`. Aptos uses SHA3-256 for authentication keys and signing message prefixes. We need either:
- `CommonCrypto` (available on Apple platforms, has `CC_SHA3_256` on iOS 17+/macOS 14+)
- Or a pure Swift SHA3 implementation as fallback

Since we target iOS 17+/macOS 14+, we can use `CommonCrypto`'s SHA3 support, which was added in those OS versions.

### 6.2 Key Type Hierarchy

```
                    ┌──────────────────┐
                    │ AccountPublicKey  │  (protocol)
                    │   - data: Data    │
                    │   - scheme        │
                    │   - verify()      │
                    └────────┬─────────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                     │
┌───────▼──────┐   ┌────────▼───────┐   ┌────────▼────────┐
│Ed25519Public │   │Secp256k1Public │   │Secp256r1Public  │
│Key           │   │Key             │   │Key (P-256)      │
└──────────────┘   └────────────────┘   └─────────────────┘

                    ┌──────────────────┐
                    │AccountPrivateKey │  (protocol)
                    │   - data: Data    │
                    │   - publicKey()   │
                    │   - sign()        │
                    └────────┬─────────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                     │
┌───────▼──────┐   ┌────────▼───────┐   ┌────────▼────────┐
│Ed25519Private│   │Secp256k1Private│   │Secp256r1Private │
│Key           │   │Key             │   │Key              │
└──────────────┘   └────────────────┘   └─────────────────┘
```

### 6.3 Protocol Definitions

```swift
/// A public key that can verify signatures.
public protocol AccountPublicKey: Serializable, Deserializable, Sendable, Hashable {
    var data: Data { get }
    func verify(message: Data, signature: any AccountSignature) throws -> Bool
}

/// A private key that can sign messages.
public protocol AccountPrivateKey: Sendable {
    associatedtype PublicKey: AccountPublicKey
    associatedtype Signature: AccountSignature

    var data: Data { get }
    func publicKey() -> PublicKey
    func sign(message: Data) throws -> Signature
}

/// A cryptographic signature.
public protocol AccountSignature: Serializable, Deserializable, Sendable, Hashable {
    var data: Data { get }
}
```

### 6.4 AnyPublicKey (Enum with Associated Values)

```swift
/// Wraps any public key variant for the SingleKey/MultiKey authentication scheme.
public enum AnyPublicKey: Serializable, Deserializable, Sendable, Hashable {
    case ed25519(Ed25519PublicKey)
    case secp256k1(Secp256k1PublicKey)
    case secp256r1(Secp256r1PublicKey)
    case keyless(KeylessPublicKey)
    case federatedKeyless(FederatedKeylessPublicKey)

    var variantIndex: UInt32 {
        switch self {
        case .ed25519: return 0
        case .secp256k1: return 1
        case .secp256r1: return 2
        case .keyless: return 3
        case .federatedKeyless: return 4
        }
    }
}
```

### 6.5 AIP-80 Private Key Formatting

```swift
public enum PrivateKeyFormat {
    /// Format a private key hex string in AIP-80 format.
    public static func format(_ hex: String, type: PrivateKeyVariant) -> String {
        switch type {
        case .ed25519: return "ed25519-priv-\(hex)"
        case .secp256k1: return "secp256k1-priv-\(hex)"
        case .secp256r1: return "secp256r1-priv-\(hex)"
        }
    }
}
```

### 6.6 Poseidon Hash

The keyless authentication flow requires Poseidon hashing for nonce derivation and identity commitment. Since no established Swift library exists, we implement a minimal Poseidon hasher matching the `poseidon-lite` parameters used by the TypeScript SDK.

---

## 7. Account System

### 7.1 Account Protocol

```swift
/// The core account protocol — all account types conform to this.
public protocol Account: Sendable {
    var accountAddress: AccountAddress { get }
    var publicKey: any AccountPublicKey { get }
    var signingScheme: SigningScheme { get }

    func sign(message: Data) throws -> any AccountSignature
    func signTransaction(_ transaction: AnyRawTransaction) throws -> any AccountSignature
    func signWithAuthenticator(message: Data) throws -> AccountAuthenticator
    func signTransactionWithAuthenticator(_ transaction: AnyRawTransaction) throws -> AccountAuthenticator
}
```

### 7.2 Account Type Diagram

```
               ┌────────────────┐
               │   Account      │  (protocol)
               └───────┬────────┘
                       │
    ┌──────────────────┼──────────────────────────┐
    │                  │                           │
┌───▼────────┐  ┌──────▼─────────┐  ┌─────────────▼──────────┐
│Ed25519     │  │SingleKey       │  │MultiKeyAccount         │
│Account     │  │Account         │  │                        │
│(legacy)    │  │(Ed25519/       │  │(M-of-N any key type)   │
│            │  │ Secp256k1/     │  │                        │
│            │  │ Secp256r1)     │  │                        │
└────────────┘  └────────────────┘  └────────────────────────┘
    │                  │                           │
    │           ┌──────▼─────────┐  ┌──────────────▼─────────┐
    │           │KeylessAccount  │  │MultiEd25519Account     │
    │           │                │  │(legacy)                │
    │           └──────┬─────────┘  └────────────────────────┘
    │                  │
    │           ┌──────▼──────────────────┐
    │           │FederatedKeylessAccount  │
    │           └─────────────────────────┘
    │
    ├─── AbstractedAccount
    └─── DerivableAbstractedAccount
```

### 7.3 Account Factory

```swift
public enum AccountFactory {
    /// Generate a new account (default: legacy Ed25519).
    public static func generate(
        scheme: SigningSchemeInput = .ed25519,
        legacy: Bool = true
    ) -> any Account { ... }

    /// Create from an existing private key.
    public static func fromPrivateKey(
        _ privateKey: any AccountPrivateKey,
        legacy: Bool = true
    ) -> any Account { ... }

    /// Derive from BIP-39 mnemonic and BIP-44 path.
    public static func fromDerivationPath(
        path: String,
        mnemonic: String,
        scheme: SigningSchemeInput = .ed25519,
        legacy: Bool = true
    ) throws -> any Account { ... }
}
```

**Difference from TypeScript:** We use a factory enum instead of static methods on an abstract class, since Swift protocols cannot have static factory methods that return `Self` for different concrete types.

### 7.4 AccountUtils

```swift
public enum AccountUtils {
    public static func toBytes(_ account: any Account) -> Data { ... }
    public static func toHexString(_ account: any Account) -> String { ... }
    public static func fromHex(_ hex: String) throws -> any Account { ... }
    public static func fromBytes(_ bytes: Data) throws -> any Account { ... }
}
```

---

## 8. Transaction System

### 8.1 Transaction Types

```swift
/// A simple single-signer transaction.
public struct SimpleTransaction: Sendable {
    public let rawTransaction: RawTransaction
    public let feePayerAddress: AccountAddress?
}

/// A multi-agent transaction with secondary signers.
public struct MultiAgentTransaction: Sendable {
    public let rawTransaction: RawTransaction
    public let secondarySignerAddresses: [AccountAddress]
    public let feePayerAddress: AccountAddress?
}

/// Either transaction type.
public enum AnyRawTransaction: Sendable {
    case simple(SimpleTransaction)
    case multiAgent(MultiAgentTransaction)
}
```

### 8.2 RawTransaction

```swift
public struct RawTransaction: Serializable, Deserializable, Sendable {
    public let sender: AccountAddress
    public let sequenceNumber: UInt64
    public let payload: TransactionPayload
    public let maxGasAmount: UInt64
    public let gasUnitPrice: UInt64
    public let expirationTimestampSecs: UInt64
    public let chainId: ChainId
}
```

### 8.3 Transaction Payloads

```swift
public enum TransactionPayload: Serializable, Deserializable, Sendable {
    case entryFunction(EntryFunction)
    case script(Script)
    case multisig(Multisig)
}

public struct EntryFunction: Serializable, Deserializable, Sendable {
    public let moduleName: ModuleId
    public let functionName: String
    public let typeArguments: [TypeTag]
    public let arguments: [Data]  // BCS-encoded arguments
}
```

### 8.4 Transaction Builder

```swift
public struct TransactionBuilder {
    private let config: AptosConfig
    private let client: AptosHTTPClient

    /// Build a simple transaction.
    public func buildSimple(
        sender: AccountAddress,
        data: InputEntryFunctionData,
        options: TransactionOptions? = nil,
        withFeePayer: Bool = false
    ) async throws -> SimpleTransaction { ... }

    /// Build a multi-agent transaction.
    public func buildMultiAgent(
        sender: AccountAddress,
        data: InputEntryFunctionData,
        secondarySignerAddresses: [AccountAddress],
        options: TransactionOptions? = nil,
        withFeePayer: Bool = false
    ) async throws -> MultiAgentTransaction { ... }
}
```

### 8.5 Transaction Flow Diagram (Swift)

```
┌─────────────────────────────────────────────────┐
│  let txn = try await aptos.transaction.build     │
│      .simple(sender:, data:)                     │
│                                                  │
│  Steps (internal):                               │
│  1. Fetch ABI (cached via LRUCache actor)        │
│  2. Fetch sequence number                        │
│  3. Fetch gas price (cached)                     │
│  4. Fetch chain ID (cached indefinitely)         │
│  5. Validate arguments against ABI               │
│  6. Construct RawTransaction                     │
└─────────────────────┬───────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────┐
│  let auth = try aptos.transaction.sign(          │
│      signer: account, transaction: txn)          │
│                                                  │
│  Steps:                                          │
│  1. Compute signing message (SHA3-256)           │
│  2. Sign with account's private key              │
│  3. Wrap in AccountAuthenticator                 │
└─────────────────────┬───────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────┐
│  let pending = try await aptos.transaction       │
│      .submit.simple(transaction: txn,            │
│                     senderAuthenticator: auth)   │
│                                                  │
│  Steps:                                          │
│  1. Construct SignedTransaction                  │
│  2. BCS-serialize                                │
│  3. POST to /transactions (BCS content type)     │
└─────────────────────┬───────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────┐
│  let committed = try await aptos.waitFor         │
│      Transaction(hash: pending.hash)             │
│                                                  │
│  Steps:                                          │
│  1. GET by_hash (check if already settled)       │
│  2. GET wait_by_hash (server long-poll)          │
│  3. Poll with exponential backoff if needed      │
│  4. Wait for indexer sync (default)              │
└─────────────────────────────────────────────────┘
```

### 8.6 Authenticator Types

```swift
/// Per-account authenticator.
public enum AccountAuthenticator: Serializable, Deserializable, Sendable {
    case ed25519(publicKey: Ed25519PublicKey, signature: Ed25519Signature)              // 0
    case multiEd25519(publicKey: MultiEd25519PublicKey, signature: MultiEd25519Signature) // 1
    case singleKey(publicKey: AnyPublicKey, signature: AnySignature)                   // 2
    case multiKey(publicKey: MultiKey, signatures: MultiKeySignature)                  // 3
    case noAccountAuthenticator                                                        // 4
    case abstraction(AccountAuthenticatorAbstraction)                                  // 5
}

/// Transaction-level authenticator.
public enum TransactionAuthenticator: Serializable, Deserializable, Sendable {
    case ed25519(publicKey: Ed25519PublicKey, signature: Ed25519Signature)              // 0
    case multiEd25519(publicKey: MultiEd25519PublicKey, signature: MultiEd25519Signature) // 1
    case multiAgent(MultiAgentAuthenticator)                                           // 2
    case feePayer(FeePayerAuthenticator)                                               // 3
    case singleSender(AccountAuthenticator)                                            // 4
}
```

### 8.7 Signing Message Computation

```swift
extension AnyRawTransaction {
    /// Compute the signing message for this transaction.
    public func signingMessage() -> Data {
        switch self {
        case .simple(let txn) where txn.feePayerAddress == nil:
            // SHA3-256("APTOS::RawTransaction" || BCS(rawTransaction))
            return sha3_256(rawTransactionSalt + txn.rawTransaction.bcsToBytes())

        case .simple(let txn):
            // Fee payer: SHA3-256("APTOS::RawTransactionWithData" || BCS(FeePayerRawTransaction))
            return sha3_256(rawTransactionWithDataSalt + bcsSerializeFeePayerRawTxn(txn))

        case .multiAgent(let txn) where txn.feePayerAddress == nil:
            return sha3_256(rawTransactionWithDataSalt + bcsSerializeMultiAgentRawTxn(txn))

        case .multiAgent(let txn):
            return sha3_256(rawTransactionWithDataSalt + bcsSerializeFeePayerRawTxn(txn))
        }
    }
}
```

### 8.8 TransactionWorker

```swift
/// Batch transaction processor using Swift structured concurrency.
public actor TransactionWorker {
    public enum Event: Sendable {
        case transactionSent(hash: String)
        case transactionSendFailed(Error)
        case transactionExecuted(hash: String)
        case transactionExecutionFailed(Error)
        case executionFinish
    }

    private let config: AptosConfig
    private let account: any Account
    private let maxWaitTime: TimeInterval
    private let maximumInFlight: Int

    /// Event stream for monitoring batch progress.
    public var events: AsyncStream<Event> { ... }

    /// Start processing enqueued transactions.
    public func start() { ... }

    /// Enqueue a transaction payload for batch processing.
    public func push(payload: InputEntryFunctionData, options: TransactionOptions? = nil) { ... }
}
```

**Difference from TypeScript:** Uses an `actor` instead of `EventEmitter`. Events are delivered via `AsyncStream<Event>`, which integrates naturally with Swift's structured concurrency (`for await event in worker.events { ... }`).

---

## 9. HTTP Client Layer

### 9.1 Architecture

```swift
/// The HTTP client actor manages URLSession and request construction.
public actor AptosHTTPClient {
    private let session: URLSession
    private let config: AptosConfig

    public init(config: AptosConfig) {
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.httpAdditionalHeaders = [
            "x-aptos-client": "aptos-swift-sdk/\(SDK_VERSION)",
            "Content-Type": "application/json",
        ]
        self.session = URLSession(configuration: sessionConfig)
        self.config = config
    }

    /// Execute a full node GET request.
    public func get<T: Decodable>(
        path: String,
        params: [String: String]? = nil,
        options: RequestOptions? = nil
    ) async throws -> T { ... }

    /// Execute a full node POST request (JSON body).
    public func post<Req: Encodable, Res: Decodable>(
        path: String,
        body: Req,
        options: RequestOptions? = nil
    ) async throws -> Res { ... }

    /// Execute a full node POST request (BCS body).
    public func postBCS<Res: Decodable>(
        path: String,
        body: Data,
        contentType: MIMEType,
        options: RequestOptions? = nil
    ) async throws -> Res { ... }
}
```

### 9.2 API Type Routing

```swift
public enum AptosAPIType: String, Sendable {
    case fullnode = "Fullnode"
    case indexer = "Indexer"
    case faucet = "Faucet"
    case pepper = "Pepper"
    case prover = "Prover"
}
```

### 9.3 Request Headers

Every request includes:
- `x-aptos-client: aptos-swift-sdk/{VERSION}`
- `Content-Type: application/json` (overridden for BCS)
- `x-aptos-swift-sdk-origin-method: {methodName}`

Plus:
- `Authorization: Bearer {API_KEY}` when configured
- `Authorization: Bearer {AUTH_TOKEN}` for faucet (API_KEY stripped for faucet requests)

### 9.4 Response Handling

```swift
public struct AptosResponse<T: Decodable>: Sendable {
    public let data: T
    public let status: Int
    public let headers: [String: String]
    public let cursor: String?      // x-aptos-cursor
    public let traceId: String?     // From traceparent header
}
```

### 9.5 Pagination

```swift
/// Collect all pages using cursor-based pagination.
public func paginateWithCursor<T: Decodable>(
    path: String,
    params: [String: String]? = nil
) async throws -> [T] {
    var allResults: [T] = []
    var cursor: String? = nil
    repeat {
        var p = params ?? [:]
        if let c = cursor { p["start"] = c }
        let response: AptosResponse<[T]> = try await get(path: path, params: p)
        allResults.append(contentsOf: response.data)
        cursor = response.cursor
    } while cursor != nil
    return allResults
}
```

### 9.6 Caching

```swift
/// Thread-safe LRU cache with TTL, implemented as an actor.
public actor LRUCache<Key: Hashable & Sendable, Value: Sendable> {
    private var storage: [Key: CacheEntry<Value>]
    private var accessOrder: [Key]
    private let maxSize: Int
    private let defaultTTL: TimeInterval

    public init(maxSize: Int = 1000, defaultTTL: TimeInterval = 300) { ... }

    public func get(_ key: Key) -> Value? { ... }
    public func set(_ key: Key, value: Value, ttl: TimeInterval? = nil) { ... }
    public func clear() { ... }
}
```

| Cached Value | TTL | Key Pattern |
|-------------|-----|-------------|
| Ledger info | 10 seconds | `"ledger-info"` |
| Gas price estimate | 5 minutes | `"gas-price"` |
| ABI lookups | 5 minutes | `"module-abi-{address}-{module}"` |
| Chain ID | Indefinite | `"chain-id"` |

---

## 10. GraphQL / Indexer Layer

### 10.1 Apollo iOS Integration

```
Indexer/
├── schema.graphqls              # Downloaded Aptos indexer schema
├── Queries/
│   ├── GetAccountOwnedTokens.graphql
│   ├── GetCollectionData.graphql
│   ├── GetTokenData.graphql
│   ├── GetFungibleAssetMetadata.graphql
│   ├── GetAccountCoinsData.graphql
│   ├── GetDelegatedStakingActivities.graphql
│   ├── GetAuthKeysForPublicKey.graphql
│   ├── GetAccountAddressesForAuthKey.graphql
│   └── ... (all indexer queries from spec)
├── Generated/                   # Apollo code generation output
│   ├── Schema/
│   ├── Operations/
│   └── Fragments/
└── IndexerClient.swift          # Wrapper around ApolloClient
```

### 10.2 IndexerClient

```swift
/// Wraps Apollo's ApolloClient for type-safe indexer queries.
public final class IndexerClient: Sendable {
    private let apollo: ApolloClient

    public init(config: AptosConfig) {
        let url = config.getRequestURL(for: .indexer)
        let store = ApolloStore(cache: InMemoryNormalizedCache())
        let provider = DefaultInterceptorProvider(store: store)
        let transport = RequestChainNetworkTransport(
            interceptorProvider: provider,
            endpointURL: url
        )
        self.apollo = ApolloClient(networkTransport: transport, store: store)
    }

    /// Execute a typed GraphQL query.
    public func query<Q: GraphQLQuery>(_ query: Q) async throws -> Q.Data { ... }

    /// Execute a raw GraphQL query string.
    public func rawQuery<T: Decodable>(query: String, variables: [String: Any]? = nil) async throws -> T { ... }
}
```

### 10.3 Code Generation

Apollo iOS code generation is configured via `apollo-codegen-config.json`:

```json
{
  "schemaDownloadConfiguration": {
    "downloadMethod": { "introspection": { "endpointURL": "https://api.mainnet.aptoslabs.com/v1/graphql" } },
    "outputPath": "./Sources/AptosSDK/Indexer/schema.graphqls"
  },
  "input": {
    "operationSearchPaths": ["./Sources/AptosSDK/Indexer/Queries/**/*.graphql"],
    "schemaSearchPaths": ["./Sources/AptosSDK/Indexer/schema.graphqls"]
  },
  "output": {
    "schemaTypes": { "path": "./Sources/AptosSDK/Indexer/Generated/Schema", "moduleType": { "embeddedInTarget": "AptosSDK" } },
    "operations": { "inSchemaModule": {} }
  }
}
```

---

## 11. API Surface

### 11.1 Domain API Pattern

Each domain API follows the same pattern:

```swift
public struct AccountAPI: Sendable {
    private let config: AptosConfig
    private let client: AptosHTTPClient
    private let indexer: IndexerClient

    init(config: AptosConfig, client: AptosHTTPClient, indexer: IndexerClient) {
        self.config = config
        self.client = client
        self.indexer = indexer
    }

    public func getAccountInfo(address: AccountAddress) async throws -> AccountData { ... }
    public func getAccountModules(address: AccountAddress, options: PaginationOptions? = nil) async throws -> [MoveModuleBytecode] { ... }
    // ... all methods from SPEC Section 9.1
}
```

### 11.2 Full API Surface (matching spec)

Each API section from the spec maps 1:1:

| Spec Section | Swift Type | Key Methods |
|-------------|-----------|-------------|
| 9.1 Account | `AccountAPI` | `getAccountInfo`, `getAccountModules`, `getAccountResources`, `getBalance`, etc. |
| 9.2 General | `GeneralAPI` | `getLedgerInfo`, `getChainId`, `view`, `viewJson`, `queryIndexer` |
| 9.3 Transaction | `TransactionAPI` | `build`, `sign`, `submit`, `simulate`, `waitForTransaction` |
| 9.4 Coin | `CoinAPI` | `transferCoinTransaction` |
| 9.5 Faucet | `FaucetAPI` | `fundAccount` |
| 9.6 Staking | `StakingAPI` | `getNumberOfDelegators`, `getDelegatedStakingActivities` |
| 9.7 Table | `TableAPI` | `getTableItem`, `getTableItemsData` |
| 9.8 Object | `ObjectAPI` | `getObjectDataByObjectAddress` |
| 10 Keyless | `KeylessAPI` | `getPepper`, `getProof`, `deriveKeylessAccount` |
| 11 Abstraction | `AccountAbstractionAPI` | `addAuthenticationFunction`, `isAccountAbstractionEnabled` |
| 12 Digital Assets | `DigitalAssetAPI` | `createCollectionTransaction`, `mintDigitalAssetTransaction`, property type handling, etc. |
| 13 Fungible Assets | `FungibleAssetAPI` | `getFungibleAssetMetadata`, `transferFungibleAsset` |
| 14 ANS | `ANSAPI` | `getOwnerAddress`, `getTargetAddress`, `registerName` |

### 11.3 Convenience Methods

```swift
extension AptosClient {
    /// Combined sign and submit in one call.
    public func signAndSubmitTransaction(
        signer: any Account,
        transaction: AnyRawTransaction,
        feePayer: (any Account)? = nil
    ) async throws -> PendingTransactionResponse { ... }

    /// Wait for a transaction to be committed.
    public func waitForTransaction(
        hash: String,
        options: WaitForTransactionOptions? = nil
    ) async throws -> CommittedTransactionResponse { ... }
}
```

### 11.4 Digital Asset Property Types (Spec 12.3)

The SDK defines a `PropertyType` enum and `PropertyValue` enum for typed digital asset properties.

#### PropertyType Enum

```swift
/// User-facing property type names that map to Move type strings.
public enum PropertyType: String, Sendable, CaseIterable {
    case boolean = "BOOLEAN"
    case u8 = "U8"
    case u16 = "U16"
    case u32 = "U32"
    case u64 = "U64"
    case u128 = "U128"
    case u256 = "U256"
    case address = "ADDRESS"
    case string = "STRING"
    case array = "ARRAY"

    /// The corresponding Move type string used on-chain.
    public var moveTypeString: String {
        switch self {
        case .boolean: return "bool"
        case .u8: return "u8"
        case .u16: return "u16"
        case .u32: return "u32"
        case .u64: return "u64"
        case .u128: return "u128"
        case .u256: return "u256"
        case .address: return "address"
        case .string: return "0x1::string::String"
        case .array: return "vector<u8>"
        }
    }
}
```

#### PropertyValue Enum

```swift
/// A property value that can be serialized to raw bytes for on-chain storage.
public enum PropertyValue: Sendable {
    case boolean(Bool)
    case u8(UInt8)
    case u16(UInt16)
    case u32(UInt32)
    case u64(UInt64)
    case u128(BigUInt)
    case u256(BigUInt)
    case address(AccountAddress)
    case string(String)
    case array(Data)

    /// Serialize this value to raw BCS bytes for on-chain property storage.
    public func toRawBytes() -> Data {
        var serializer = Serializer()
        switch self {
        case .boolean(let v): serializer.serializeBool(v)
        case .u8(let v): serializer.serializeU8(v)
        case .u16(let v): serializer.serializeU16(v)
        case .u32(let v): serializer.serializeU32(v)
        case .u64(let v): serializer.serializeU64(v)
        case .u128(let v): serializer.serializeU128(v)
        case .u256(let v): serializer.serializeU256(v)
        case .address(let v): v.serialize(to: &serializer)
        case .string(let v): serializer.serializeStr(v)
        case .array(let v): serializer.serializeBytes(v)
        }
        return serializer.output()
    }
}
```

**Difference from TypeScript:** TypeScript uses loose union types (`boolean | number | bigint | string | AccountAddress | Uint8Array`) where the correct serialization is inferred at runtime. Swift uses an enum with associated values, making the type/value pairing explicit and compile-time safe. Each `PropertyValue` variant directly corresponds to a `PropertyType`, eliminating runtime type-guessing.

#### Validation

When building digital asset transactions with typed properties:
- `propertyKeys`, `propertyTypes`, and `propertyValues` arrays SHALL have matching lengths.
- Mismatched lengths SHALL throw `AptosError.invalidArgument`.
- `propertyTypes` are converted from `PropertyType` enum cases to Move type strings via `.moveTypeString`.
- `propertyValues` are serialized to raw bytes via `.toRawBytes()`.

```swift
/// Validate and prepare property arrays for digital asset transactions.
public static func prepareProperties(
    keys: [String],
    types: [PropertyType],
    values: [PropertyValue]
) throws -> (keys: [String], types: [String], values: [Data]) {
    guard keys.count == types.count, types.count == values.count else {
        throw AptosError.invalidArgument(
            "propertyKeys, propertyTypes, and propertyValues must have matching lengths"
        )
    }
    return (
        keys: keys,
        types: types.map(\.moveTypeString),
        values: values.map { $0.toRawBytes() }
    )
}
```

---

## 12. Keyless Authentication

### 12.1 EphemeralKeyPair

```swift
public struct EphemeralKeyPair: Serializable, Deserializable, Sendable {
    public let privateKey: Curve25519.Signing.PrivateKey  // Ed25519 by default
    public let publicKey: EphemeralPublicKey
    public let blinder: Data              // 31 bytes
    public let expiryDateSecs: UInt64
    public let nonce: String              // Poseidon hash derived

    public static func generate(
        scheme: EphemeralPublicKeyVariant = .ed25519,
        expiryDateSecs: UInt64? = nil     // Default: 24h from now
    ) -> EphemeralKeyPair { ... }

    public func isExpired() -> Bool {
        UInt64(Date().timeIntervalSince1970) >= expiryDateSecs
    }
}
```

### 12.2 KeylessAccount

```swift
public final class KeylessAccount: Account, @unchecked Sendable {
    public let accountAddress: AccountAddress
    public let publicKey: KeylessPublicKey
    public let signingScheme: SigningScheme = .singleKey

    private let ephemeralKeyPair: EphemeralKeyPair
    private let jwt: String
    private let uidKey: String
    private let pepper: Data
    private var proof: ZeroKnowledgeSig?
    private let proofPromise: Task<ZeroKnowledgeSig, Error>?

    public func sign(message: Data) async throws -> any AccountSignature {
        // 1. Ensure proof is available (await if async)
        let proof = try await resolveProof()
        // 2. Validate not expired
        guard !ephemeralKeyPair.isExpired() else { throw KeylessError.ephemeralKeyPairExpired }
        // 3. Sign with ephemeral key
        // 4. Construct KeylessSignature
        ...
    }
}
```

**Difference from TypeScript:** Uses a `Task<ZeroKnowledgeSig, Error>` for async proof fetching instead of a `Promise`. The `sign` method is `async` which naturally integrates with Swift concurrency.

### 12.3 Poseidon Hash

Custom minimal implementation for nonce derivation and identity commitment:

```swift
/// Minimal Poseidon hash for keyless nonce/identity commitment computation.
enum Poseidon {
    /// Hash inputs using the Poseidon hash function over BN254 scalar field.
    static func hash(_ inputs: [BigUInt]) -> BigUInt { ... }
}
```

---

## 13. Account Abstraction

### 13.1 AbstractedAccount

```swift
public final class AbstractedAccount: Account, @unchecked Sendable {
    public let accountAddress: AccountAddress
    public let publicKey: AbstractPublicKey
    public let signingScheme: SigningScheme = .abstraction
    public let authenticationFunction: MoveFunctionId

    /// Custom signer callback — receives a SHA3 digest, returns custom auth bytes.
    private var abstractSigner: @Sendable (Data) async throws -> Data

    public func signTransactionWithAuthenticator(
        _ transaction: AnyRawTransaction
    ) async throws -> AccountAuthenticator {
        // 1. Compute standard signing message
        let signingMessage = transaction.signingMessage()
        // 2. Create AccountAbstractionMessage (V1)
        let aaMessage = AccountAbstractionMessage.v1(
            originalMessage: signingMessage,
            authFunction: authenticationFunction
        )
        // 3. Hash: SHA3-256("APTOS::AASigningData" || BCS(aaMessage))
        let aaBytes = sha3_256(aaSigningDataSalt + aaMessage.bcsToBytes())
        // 4. Hash again for 32-byte digest
        let digest = sha3_256(aaBytes)
        // 5. Call custom signer
        let signature = try await abstractSigner(digest)
        // 6. Return AccountAuthenticatorAbstraction
        return .abstraction(.init(
            functionInfo: authenticationFunction,
            digest: digest,
            signature: signature
        ))
    }
}
```

### 13.2 DerivableAbstractedAccount

```swift
public final class DerivableAbstractedAccount: AbstractedAccount {
    public let accountIdentity: Data

    public static func computeAccountAddress(
        authenticationFunction: MoveFunctionId,
        abstractPublicKey: Data,
        domainSeparator: String? = nil
    ) -> AccountAddress {
        // SHA3(moduleAddress || moduleName || functionName || abstractPublicKey || domainSeparator)
        ...
    }
}
```

---

## 14. Error Handling

### 14.1 Error Type Hierarchy

```swift
/// Base SDK error type.
public enum AptosError: Error, Sendable {
    case configurationError(String)
    case serializationError(String)
    case deserializationError(String)
    case cryptoError(String)
    case invalidArgument(String)
}

/// HTTP API error with full context.
public struct AptosAPIError: Error, Sendable {
    public let url: String
    public let status: Int
    public let statusText: String
    public let data: String
    public let apiType: AptosAPIType
    public let traceId: String?

    public var localizedDescription: String {
        let truncatedData = data.count > 400
            ? "\(data.prefix(200))...\(data.suffix(200))"
            : data
        return "[\(apiType)] \(url) - \(status) \(statusText): \(truncatedData)"
    }
}

/// Transaction wait timeout error.
public struct WaitForTransactionError: Error, Sendable {
    public let lastSubmittedTransaction: TransactionResponse?
}

/// Failed transaction (committed but success=false).
public struct FailedTransactionError: Error, Sendable {
    public let transaction: CommittedTransactionResponse
    public var vmStatus: String { transaction.vmStatus }
}

/// Keyless authentication errors.
public struct KeylessError: Error, Sendable {
    public let type: KeylessErrorType
    public let category: KeylessErrorCategory
    public let resolutionTip: String
    public let innerError: (any Error)?
    public let details: String?
}
```

### 14.2 Error Categories (KeylessError)

```swift
public enum KeylessErrorCategory: String, Sendable {
    case apiError = "API_ERROR"
    case externalAPIError = "EXTERNAL_API_ERROR"
    case sessionExpired = "SESSION_EXPIRED"
    case invalidState = "INVALID_STATE"
    case invalidSignature = "INVALID_SIGNATURE"
    case unknown = "UNKNOWN"
}
```

---

## 15. Concurrency Model

### 15.1 Sendable Compliance

All public types SHALL conform to `Sendable`:

| Type Category | Swift Pattern |
|--------------|--------------|
| Value types (configs, addresses, keys, signatures) | `struct` (automatically `Sendable`) |
| Domain APIs (AccountAPI, etc.) | `struct` conforming to `Sendable` |
| HTTP client | `actor AptosHTTPClient` |
| LRU Cache | `actor LRUCache` |
| TransactionWorker | `actor TransactionWorker` |
| KeylessAccount | `final class` with `@unchecked Sendable` (internal synchronization) |
| AptosClient | `final class` conforming to `Sendable` (all properties immutable) |

### 15.2 Actor Usage

```
┌─────────────────────────────────────────────────┐
│  Actors (isolated mutable state)                 │
│                                                  │
│  AptosHTTPClient   — URLSession management       │
│  LRUCache          — thread-safe caching         │
│  TransactionWorker — batch transaction queue      │
│  AccountSequenceNumber — sequence number alloc    │
└─────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────┐
│  Sendable structs (immutable / value types)      │
│                                                  │
│  AptosConfig, AccountAddress, RawTransaction,    │
│  all key/signature types, all API structs        │
└─────────────────────────────────────────────────┘
```

### 15.3 Async Patterns

```swift
// All API methods use async/await
let info = try await aptos.account.getAccountInfo(address: addr)

// Batch processing with AsyncStream
for await event in worker.events {
    switch event {
    case .transactionExecuted(let hash):
        print("Committed: \(hash)")
    case .transactionExecutionFailed(let error):
        print("Failed: \(error)")
    default: break
    }
}

// Concurrent operations with task groups
async let balance = aptos.account.getBalance(address: addr)
async let info = aptos.account.getAccountInfo(address: addr)
let (b, i) = try await (balance, info)
```

---

## 16. Differences from TypeScript SDK

### 16.1 Structural Differences

| Aspect | TypeScript SDK | Swift SDK | Rationale |
|--------|---------------|-----------|-----------|
| Abstract class `Account` | `abstract class` | `protocol Account` | Swift uses protocols for polymorphism |
| Account factory | Static methods on `Account` | `enum AccountFactory` | Protocols can't have static factory methods returning different types |
| EventEmitter | `eventemitter3` | `actor` + `AsyncStream` | Native Swift concurrency patterns |
| TransactionWorker | `extends EventEmitter` | `actor` with `AsyncStream<Event>` | Actor isolation provides thread safety |
| Serializer pool | 8-instance object pool | `~Copyable` struct (stack allocated) | No heap allocation, no pooling needed |
| BigInt | Native `BigInt` | `BigUInt`/`BigInt` from library | Swift lacks native arbitrary-precision integers |
| HTTP client | `@aptos-labs/aptos-client` | `URLSession` | Native Apple networking |
| GraphQL | Raw HTTP POST | Apollo iOS | Type-safe code generation |
| Module system | ESM/CJS dual | Swift Package Manager | Single module format |
| Error handling | `throw new Error()` | `throws` / typed errors | Swift's type-safe error handling |
| Null/undefined | `null \| undefined` | `Optional<T>` (`T?`) | Single nil representation |
| PropertyValue | Loose union `boolean \| number \| bigint \| string \| AccountAddress \| Uint8Array` | `enum PropertyValue` with associated values | Compile-time type safety; explicit pairing of type and value |

### 16.2 API Naming Convention Changes

TypeScript uses camelCase; Swift follows Apple API Design Guidelines:

| TypeScript | Swift |
|-----------|-------|
| `getAccountInfo({ accountAddress })` | `getAccountInfo(address:)` |
| `signAndSubmitTransaction({ signer, transaction })` | `signAndSubmitTransaction(signer:transaction:)` |
| `waitForTransaction({ transactionHash })` | `waitForTransaction(hash:options:)` |

### 16.3 Missing Swift Equivalents

| TypeScript Feature | Swift Approach |
|-------------------|----------------|
| `jwt-decode` | Manual JWT base64 decoding (JWT is just base64-encoded JSON) |
| `poseidon-lite` | Custom Poseidon implementation |
| `@aptos-labs/aptos-client` | `URLSession` |

### 16.4 Swift-Specific Advantages

| Feature | Benefit |
|---------|---------|
| Value types (`struct`) | Copy-on-write semantics, no reference counting for most types |
| `~Copyable` Serializer | Zero-copy buffer extraction, no pooling overhead |
| Native `CryptoKit` | Hardware-accelerated Ed25519 and P-256 on Apple silicon |
| `actor` isolation | Compile-time thread safety guarantees |
| Strong typing | No runtime type errors for BCS serialization |
| `Codable` | Built-in JSON encoding/decoding with compile-time safety |
| Swift 6 strict concurrency | Data race freedom guaranteed by compiler |

---

## 17. Performance Considerations

### 17.1 BCS Serialization

- **Buffer strategy:** Pre-allocate based on expected transaction size (~512 bytes for typical transactions).
- **~Copyable Serializer:** Avoids heap allocation and reference counting. Buffer is stack-promoted for small sizes.
- **Data vs [UInt8]:** Use `Data` for interop with Foundation/CryptoKit. `Data` has copy-on-write and contiguous storage.

### 17.2 Cryptographic Operations

- **CryptoKit hardware acceleration:** Ed25519 and P-256 operations leverage the Secure Enclave on Apple devices.
- **Key generation:** `Curve25519.Signing.PrivateKey()` uses the system CSPRNG.
- **SHA3-256:** Use CommonCrypto's native implementation on iOS 17+/macOS 14+ for maximum performance.

### 17.3 Networking

- **URLSession HTTP/2:** Automatic multiplexing reduces connection overhead for parallel API calls.
- **JSON decoding:** Use `JSONDecoder` with pre-configured date/number strategies. Consider `@inlinable` for hot-path Codable conformances.
- **Connection pooling:** URLSession handles connection pooling and keep-alive automatically.

### 17.4 Caching

- **Actor-based LRU cache:** No lock contention; actor serializes access with efficient FIFO scheduling.
- **10% eviction:** When at capacity, evict ~100 entries (10% of 1000) to amortize eviction cost.
- **TTL cleanup:** Periodic cleanup every 60 seconds via a background `Task`.

### 17.5 Memory

- **Transaction history limits:** `TransactionWorker` caps history at 10,000 entries with 10% eviction, matching TypeScript SDK.
- **GraphQL cache:** Apollo's `InMemoryNormalizedCache` should be configured with appropriate size limits.

---

## 18. Dependencies

### 18.1 Dependency Table

| Dependency | Version | Purpose | TypeScript Equivalent |
|-----------|---------|---------|----------------------|
| `secp256k1.swift` (GigaBitcoin) | ^0.18.0 | Secp256k1 ECDSA | `@noble/curves` |
| `apollo-ios` | ^1.15.0 | GraphQL client + codegen | Manual HTTP POST |
| `BigInt` (attaswift) | ^5.4.0 | Arbitrary-precision integers for u128/u256 | Native `BigInt` |
| `Bip39` | ^1.0.0 | BIP-39 mnemonic generation/derivation | `@scure/bip39` |
| Apple `CryptoKit` | (system) | Ed25519, P-256, SHA-256 | `@noble/curves`, `@noble/hashes` |
| Apple `CommonCrypto` | (system) | SHA3-256 | `@noble/hashes` |
| Apple `Foundation` | (system) | Data, URLSession, JSONEncoder/Decoder | Various |

### 18.2 No-Dependency Alternatives Considered

| Component | Could Replace | Tradeoff |
|-----------|--------------|----------|
| `BigInt` | Custom u128/u256 structs | Higher maintenance, but avoids dependency. Could implement as fixed-width types for better perf. |
| `apollo-ios` | Raw HTTP + manual Codable | Less type safety, more boilerplate, but zero GraphQL dependency |
| `Bip39` | Manual BIP-39/32 implementation | Significant effort, security risk |

---

## 19. Testing Strategy

### 19.1 Test Pyramid

```
         ┌─────────────────┐
         │    E2E Tests     │  (devnet integration)
         │  ~20% coverage   │
         └────────┬────────┘
                  │
         ┌────────▼────────┐
         │ Integration Tests│  (mock HTTP, real BCS/crypto)
         │  ~30% coverage   │
         └────────┬────────┘
                  │
         ┌────────▼────────┐
         │   Unit Tests     │  (pure logic, serialization, crypto)
         │  ~50% coverage   │
         └─────────────────┘
```

### 19.2 Unit Tests

| Module | Test Focus |
|--------|-----------|
| `BCS/` | Roundtrip serialization for all types, edge cases (max values, empty vectors), ULEB128 encoding |
| `Core/Crypto/` | Key generation, signing, verification, known test vectors from TypeScript SDK |
| `Core/AccountAddress` | Parsing, short/long form, special addresses, validation |
| `Core/AuthenticationKey` | Derivation from all key types |
| `Core/TypeTag` | Parsing from strings, serialization |
| `Account/` | Account creation, serialization/deserialization roundtrips |
| `Transactions/` | Payload construction, signing message computation, authenticator serialization |

### 19.3 Integration Tests

| Area | Approach |
|------|----------|
| HTTP Client | Mock `URLProtocol` to intercept requests, verify headers/paths/bodies |
| Pagination | Mock paginated responses, verify cursor handling |
| ABI Fetching | Mock module endpoint, verify argument validation |
| Caching | Verify TTL expiration, LRU eviction, cache hits |

### 19.4 E2E Tests (Devnet)

| Scenario | Description |
|----------|-------------|
| Account creation + funding | Generate account, fund via faucet, verify balance |
| Simple transfer | Build, sign, submit, wait for APT transfer |
| Multi-agent transaction | Two signers authorize a transaction |
| Fee payer transaction | Third party pays gas |
| View function | Call a read-only Move function |
| NFT operations | Create collection, mint token, transfer |
| Fungible asset transfer | Transfer custom fungible asset |
| Key rotation | Rotate auth key and verify |

### 19.5 Cross-Validation with TypeScript SDK

Known test vectors SHALL be extracted from the TypeScript SDK tests for:
- BCS serialization outputs (byte-for-byte comparison)
- Signing message computation (hash comparison)
- AccountAddress derivation from public keys
- Authentication key derivation
- Transaction authenticator serialization

---

## 20. Formatting & Linting

### 20.1 SwiftFormat

Configuration (`.swiftformat`):

```
--indent 4
--self remove
--stripunusedargs closure-only
--wraparguments before-first
--wrapcollections before-first
--maxwidth 120
--swiftversion 6.0
```

### 20.2 SwiftLint

Configuration (`.swiftlint.yml`):

```yaml
opt_in_rules:
  - closure_body_length
  - empty_count
  - explicit_init
  - fatal_error_message
  - force_unwrapping
  - implicitly_unwrapped_optional
  - missing_docs
  - multiline_arguments
  - vertical_whitespace_closing_braces

disabled_rules:
  - todo
  - trailing_comma

line_length:
  warning: 120
  error: 200

file_length:
  warning: 500
  error: 1000

type_body_length:
  warning: 300
  error: 500
```

### 20.3 Pre-Commit Hooks

```bash
#!/bin/sh
# .git/hooks/pre-commit

# Format
swiftformat --lint Sources/ Tests/

# Lint
swiftlint lint Sources/ Tests/

# Test
swift test
```

### 20.4 CI/CD Pipeline

```yaml
# .github/workflows/ci.yml
jobs:
  build-and-test:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      - name: SwiftFormat Check
        run: swiftformat --lint Sources/ Tests/
      - name: SwiftLint
        run: swiftlint lint Sources/ Tests/
      - name: Build
        run: swift build
      - name: Unit Tests
        run: swift test --filter AptosSDKTests
      - name: E2E Tests (Devnet)
        run: swift test --filter E2E
        env:
          APTOS_NETWORK: devnet
```

---

## 21. Implementation Plan

### Phase 1: Foundation (Core + BCS)
1. Set up SPM project structure and `Package.swift`
2. Implement `BCS/Serializer` and `BCS/Deserializer`
3. Implement `Hex`, `AccountAddress`, `AuthenticationKey`
4. Implement Ed25519 key types (using CryptoKit)
5. Implement Secp256k1 key types (using secp256k1.swift)
6. Implement Secp256r1 key types (using CryptoKit P-256)
7. Implement `AnyPublicKey`, `AnySignature` enums
8. Unit tests for BCS roundtrips and crypto operations
9. Set up SwiftFormat and SwiftLint

### Phase 2: Account System
1. Define `Account` protocol
2. Implement `Ed25519Account`, `SingleKeyAccount`
3. Implement `MultiKeyAccount`, `MultiEd25519Account`
4. Implement `AccountFactory`
5. Implement `AccountUtils` serialization
6. Implement BIP-39/BIP-44 key derivation
7. Unit tests with known test vectors

### Phase 3: Transaction System
1. Implement `RawTransaction`, `SimpleTransaction`, `MultiAgentTransaction`
2. Implement transaction payloads (entry function, script, multisig)
3. Implement `TransactionBuilder`
4. Implement signing message computation
5. Implement all authenticator types
6. Implement `SignedTransaction` BCS serialization
7. Unit tests for signing and serialization

### Phase 4: HTTP Client + Configuration
1. Implement `AptosConfig` and `Network` types
2. Implement `AptosHTTPClient` actor (URLSession)
3. Implement request/response types with `Codable`
4. Implement pagination (cursor and offset)
5. Implement `LRUCache` actor
6. Implement error types (`AptosAPIError`, etc.)
7. Integration tests with mock URLProtocol

### Phase 5: API Surface (Core APIs)
1. Implement `AptosClient` (main entry point)
2. Implement `GeneralAPI` (ledger info, chain ID, view functions)
3. Implement `AccountAPI` (account info, resources, modules, balance)
4. Implement `TransactionAPI` (build, sign, submit, wait, simulate)
5. Implement `CoinAPI` (transfer)
6. Implement `FaucetAPI` (fund account)
7. E2E tests: account creation, funding, simple transfer

### Phase 6: GraphQL / Indexer
1. Set up Apollo iOS code generation
2. Download and configure Aptos indexer schema
3. Write all GraphQL query files
4. Generate typed query code
5. Implement `IndexerClient`
6. Wire indexer queries into domain APIs
7. Integration tests for indexer queries

### Phase 7: Extended APIs
1. Implement `PropertyType` enum and `PropertyValue` enum with BCS serialization
2. Implement `DigitalAssetAPI` (NFT operations including typed property handling)
3. Implement `FungibleAssetAPI`
4. Implement `StakingAPI`
5. Implement `TableAPI`
6. Implement `ObjectAPI`
7. Implement `ANSAPI` (Aptos Name Service)
8. Unit tests for PropertyType/PropertyValue serialization and validation
9. E2E tests for NFT mint/transfer with typed properties, fungible asset operations

### Phase 8: Keyless Authentication
1. Implement `EphemeralKeyPair`
2. Implement Poseidon hash (for nonce derivation)
3. Implement `KeylessPublicKey`, `KeylessSignature`
4. Implement `KeylessAccount` with async proof fetching
5. Implement `FederatedKeylessAccount`
6. Implement pepper and prover service clients
7. Implement `KeylessAPI`
8. Unit tests + E2E tests with test OIDC tokens

### Phase 9: Account Abstraction
1. Implement `AbstractedAccount`
2. Implement `DerivableAbstractedAccount`
3. Implement `AccountAbstractionAPI`
4. Implement abstraction signing flow (AA message, digest)
5. Unit tests for signing flow
6. E2E tests with permissioned signer

### Phase 10: Batch Processing & Polish
1. Implement `TransactionWorker` actor
2. Implement `AccountSequenceNumber` actor
3. Implement TransactionSubmitter plugin support
4. Final documentation pass
5. Performance profiling and optimization
6. Full E2E test suite validation against devnet
7. Release preparation (version tagging, README)
