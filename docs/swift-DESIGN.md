# Aptos Swift SDK — Design Document

## Overview

The Aptos Swift SDK provides a comprehensive, type-safe interface for interacting with the Aptos blockchain from Apple platforms. It targets **Tier 3 (Full Compliance)** with the [aptos-sdk-specs v1.0.0](https://github.com/aptos-labs/aptos-sdk-specs), implementing all P0, P1, and P2 requirements.

**Key design principles:**
- **Apple-native**: CryptoKit for Ed25519/P-256, URLSession for networking, `actor` for concurrency
- **Value-type-first**: All core types are structs (copy-on-write, stack-allocated where possible)
- **Zero-copy where feasible**: `withUnsafeBytes` for crypto operations
- **Minimal dependencies**: Only `secp256k1.swift` (P256K) and `BigInt`

---

## Platform Requirements

| Platform | Minimum Version |
|----------|-----------------|
| iOS      | 17.0            |
| macOS    | 14.0            |
| watchOS  | 10.0            |
| tvOS     | 17.0            |
| Swift    | 6.0             |

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         AptosClient                                 │
│  Unified entry point composing all domain APIs                      │
│                                                                     │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌───────────┐ ┌─────────┐ │
│  │ account  │ │   coin   │ │ digital  │ │  fungible │ │   ans   │ │
│  │   API    │ │   API    │ │  asset   │ │   asset   │ │   API   │ │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └─────┬─────┘ └────┬────┘ │
│       │             │            │              │            │      │
│  ┌────┴─────┐ ┌─────┴────┐ ┌────┴─────┐ ┌─────┴────┐ ┌─────┴───┐ │
│  │ general  │ │   txn    │ │  faucet  │ │  staking │ │ keyless │ │
│  │   API    │ │   API    │ │   API    │ │   API    │ │   API   │ │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └─────┬────┘ └────┬────┘ │
│       │             │            │              │           │      │
│  ┌────┴─────┐ ┌─────┴────┐ ┌────┴─────┐ ┌─────┴────┐           │ │
│  │  event   │ │  object  │ │  table   │ │  indexer │           │ │
│  │   API    │ │   API    │ │   API    │ │  client  │           │ │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘           │ │
│                                                                     │
│                     ┌─────────────────┐                             │
│                     │ AptosHTTPClient │ (actor)                     │
│                     │  GET / POST /   │                             │
│                     │  POST-BCS       │                             │
│                     └────────┬────────┘                             │
│                              │                                      │
│                     ┌────────┴────────┐                             │
│                     │   AptosConfig   │                             │
│                     │  Network URLs   │                             │
│                     │  Timeouts/Keys  │                             │
│                     └─────────────────┘                             │
└─────────────────────────────────────────────────────────────────────┘
```

### Module Dependency Graph

```
AptosClient
    ├── API Layer (GeneralAPI, AccountAPI, TransactionAPI, ViewAPI, ...)
    │       ├── AptosHTTPClient (actor)
    │       ├── AptosConfig
    │       └── Types (APITypes, MoveTypes, TransactionTypes)
    ├── Transactions
    │       ├── RawTransaction / SignedTransaction
    │       ├── TransactionPayload / EntryFunction
    │       ├── TransactionAuthenticator / AccountAuthenticator
    │       ├── TransactionBuilder (fluent)
    │       └── Signer (domain-separated signing)
    ├── Accounts
    │       ├── AptosAccount (protocol)
    │       ├── Ed25519Account (legacy scheme)
    │       ├── SingleKeyAccount (unified scheme)
    │       ├── MultiKeyAccount (M-of-N)
    │       └── KeylessAccount (OIDC)
    ├── Core / Crypto
    │       ├── Ed25519 (CryptoKit Curve25519.Signing)
    │       ├── Secp256k1 (P256K library)
    │       ├── Secp256r1 (CryptoKit P256)
    │       ├── AnyPublicKey / AnySignature (type-erased wrappers)
    │       ├── MultiKey / MultiEd25519 (multi-sig primitives)
    │       ├── AuthenticationKey (key → address derivation)
    │       └── Hashing (SHA3-256, SHA2-256, domain separation)
    ├── Core / Types
    │       ├── AccountAddress (32-byte, hex encoding)
    │       ├── TypeTag / StructTag (Move type system)
    │       ├── Hex (encode/decode utilities)
    │       └── Network / Endpoints
    └── BCS
            ├── Serializer (~Copyable, dynamic buffer)
            ├── Deserializer (~Copyable, cursor-based)
            └── BCSSerializable / BCSDeserializable protocols
```

---

## BCS Serialization

Binary Canonical Serialization (BCS) is the wire format for all Aptos blockchain data.

### Design

```swift
// ~Copyable struct prevents accidental aliasing of internal buffer
public struct Serializer: ~Copyable {
    private var data: Data

    mutating func serializeBool(_ value: Bool)
    mutating func serializeU8(_ value: UInt8)
    mutating func serializeU16(_ value: UInt16)
    mutating func serializeU32(_ value: UInt32)
    mutating func serializeU64(_ value: UInt64)
    mutating func serializeU128(_ value: BigUInt)
    mutating func serializeU256(_ value: BigUInt)
    mutating func serializeBytes(_ value: Data)         // ULEB128 length prefix
    mutating func serializeFixedBytes(_ value: Data)    // No length prefix
    mutating func serializeStr(_ value: String)
    mutating func serializeU32AsUleb128(_ value: UInt32)
    mutating func serializeOption<T: BCSSerializable>(_ value: T?)
    mutating func serializeVector<T: BCSSerializable>(_ values: [T])

    consuming func toBytes() -> Data
}

public struct Deserializer: ~Copyable {
    private let data: Data
    private var offset: Int

    mutating func deserializeBool() throws -> Bool
    mutating func deserializeU8() throws -> UInt8
    // ... matching methods
    mutating func assertFinished() throws
}
```

### Protocols

```swift
public protocol BCSSerializable: Sendable {
    func serialize(to serializer: inout Serializer) throws
}

public protocol BCSDeserializable: Sendable {
    static func deserialize(from deserializer: inout Deserializer) throws -> Self
}

// Convenience top-level helpers
public func bcsToBytes<T: BCSSerializable>(_ value: T) throws -> Data
public func bcsFromBytes<T: BCSDeserializable>(_ type: T.Type, _ data: Data) throws -> T
```

### Type Mapping

| BCS Type | Swift Type |
|----------|-----------|
| bool     | `Bool`    |
| u8       | `UInt8`   |
| u16      | `UInt16`  |
| u32      | `UInt32`  |
| u64      | `UInt64`  |
| u128     | `BigUInt` |
| u256     | `BigUInt` |
| bytes    | `Data`    |
| string   | `String`  |
| vector<T>| `[T]`    |
| option<T>| `T?`     |

---

## Cryptography

### Ed25519 (CryptoKit — Hardware Accelerated)

```
Ed25519PrivateKey (32 bytes)
    │
    ├─ publicKey() → Ed25519PublicKey (32 bytes)
    ├─ sign(Data) → Ed25519Signature (64 bytes)
    ├─ toAIP80() → "ed25519-priv-0x..."
    └─ fromHex() / fromAIP80() (construction)

Ed25519PublicKey
    └─ verify(message:signature:) → Bool
```

Uses `Curve25519.Signing` from CryptoKit (Apple Silicon hardware acceleration).

### Secp256k1 (P256K Library)

```
Secp256k1PrivateKey (32 bytes)
    │
    ├─ publicKey() → Secp256k1PublicKey (33 bytes, compressed)
    ├─ sign(Data) → Secp256k1Signature (64 bytes, low-S normalized)
    └─ toAIP80() → "secp256k1-priv-0x..."

Secp256k1PublicKey
    └─ verify(message:signature:) → Bool
```

Signing uses SHA3-256 for message digest, RFC 6979 deterministic nonces, low-S normalization.

### Secp256r1 / P-256 (CryptoKit — WebAuthn/Passkeys)

```
Secp256r1PrivateKey
    │
    ├─ publicKey() → Secp256r1PublicKey (33 bytes, compressed)
    └─ sign(Data) → Secp256r1Signature (64 bytes)

Secp256r1PublicKey
    └─ verify(message:signature:) → Bool
```

Uses CryptoKit `P256.Signing` for WebAuthn/passkey compatibility.

### SHA3-256 (Custom Keccak Implementation)

CryptoKit provides SHA-256 but **not** SHA3-256. The SDK includes a minimal, auditable implementation of Keccak-f[1600] with SHA3 domain separation (padding byte 0x06, not Keccak's 0x01).

```
SHA3.sha256([UInt8]) → Data    // Custom Keccak-f[1600]
AptosHashing.sha2_256(Data) → Data   // CryptoKit SHA-256
AptosHashing.sha3_256(Data) → Data   // Wrapper around SHA3
AptosHashing.signingPrefix(String) → Data  // SHA3-256(domain)
```

### Authentication Key Derivation

```
AuthenticationKey = SHA3-256(publicKeyBytes || signingScheme)

Schemes:
    0 = Ed25519 (legacy)
    1 = MultiEd25519 (legacy)
    2 = SingleKey (unified)
    3 = MultiKey (multi-sig)

AccountAddress = AuthenticationKey (for new accounts, the 32-byte auth key IS the address)
```

### AIP-80 Private Key Format

All private keys support AIP-80 serialization:
```
ed25519-priv-0x<hex>
secp256k1-priv-0x<hex>
```

---

## Account Types

### Protocol Hierarchy

```swift
public protocol AptosAccount: Sendable {
    var accountAddress: AccountAddress { get }
    var signingScheme: SigningScheme { get }
    func sign(message: Data) throws -> AnySignature
    func signWithAuthenticator(message: Data) throws -> AccountAuthenticator
    func authenticationKey() throws -> AuthenticationKey
}
```

### Account Types

| Type | Scheme | Keys | Use Case |
|------|--------|------|----------|
| `Ed25519Account` | Ed25519 (0) | Ed25519 only | Legacy accounts |
| `SingleKeyAccount` | SingleKey (2) | Ed25519/Secp256k1/Secp256r1 | Recommended for new accounts |
| `MultiKeyAccount` | MultiKey (3) | Mixed key types | M-of-N multi-sig |
| `KeylessAccount` | SingleKey (2) | OIDC + ephemeral | Social login |

### Type-Erased Key Wrappers

```
AnyPublicKey (enum)
    ├─ .ed25519(Ed25519PublicKey)       variant 0
    ├─ .secp256k1(Secp256k1PublicKey)   variant 1
    ├─ .secp256r1(Secp256r1PublicKey)   variant 2
    └─ .keyless(KeylessPublicKey)       variant 3

AnySignature (enum)
    ├─ .ed25519(Ed25519Signature)       variant 0
    ├─ .secp256k1(Secp256k1Signature)   variant 1
    ├─ .webAuthn(WebAuthnSignature)     variant 2
    └─ .keyless(KeylessSignature)       variant 3
```

---

## Transaction Lifecycle

### Building

```
TransactionBuilder()                           Fluent builder
    .sender(address)
    .sequenceNumber(n)
    .payload(.entryFunction(...))
    .maxGasAmount(200_000)                     Default
    .gasUnitPrice(100)                         Default
    .expirationTimestampSecs(now + 20s)        Default
    .chainId(.testnet)
    .build()
    → RawTransaction
```

### Transaction Types

```
SimpleTransaction
    ├─ rawTransaction: RawTransaction
    └─ feePayerAddress: AccountAddress?

MultiAgentTransaction
    ├─ rawTransaction: RawTransaction
    ├─ secondarySignerAddresses: [AccountAddress]
    └─ feePayerAddress: AccountAddress?

AnyRawTransaction (enum)
    ├─ .simple(SimpleTransaction)
    └─ .multiAgent(MultiAgentTransaction)
```

### Signing

Domain-separated signing prevents cross-domain replay attacks:

```
Single Signer:
    signingMessage = SHA3-256("APTOS::RawTransaction") || BCS(rawTransaction)

Multi-Agent:
    signingMessage = SHA3-256("APTOS::RawTransactionWithData")
                     || BCS(variant=0 || rawTransaction || secondaryAddresses)

Fee Payer:
    signingMessage = SHA3-256("APTOS::RawTransactionWithData")
                     || BCS(variant=1 || rawTransaction || secondaryAddresses || feePayerAddress)
```

### Authenticators

```
AccountAuthenticator (per-account)
    ├─ .ed25519(pubKey, sig)           variant 0 (legacy)
    ├─ .multiEd25519(pubKey, sig)      variant 1 (legacy)
    ├─ .singleKey(pubKey, sig)         variant 2 (unified)
    ├─ .multiKey(pubKey, sig)          variant 3 (multi-sig)
    ├─ .noAccountAuthenticator         variant 4 (simulation)
    └─ .abstraction(funcInfo, data)    variant 5 (account abstraction)

TransactionAuthenticator (top-level)
    ├─ .ed25519(pubKey, sig)           variant 0
    ├─ .multiEd25519(pubKey, sig)      variant 1
    ├─ .multiAgent(sender, addrs, sigs)  variant 2
    ├─ .feePayer(sender, addrs, sigs, feePayer, feePayerAuth)  variant 3
    └─ .singleSender(AccountAuthenticator)  variant 4
```

### Submission

```
SignedTransaction
    ├─ rawTransaction: RawTransaction
    └─ authenticator: TransactionAuthenticator

Serialized as BCS → POST /v1/transactions
    Content-Type: application/x.aptos.signed_transaction+bcs
```

---

## Networking

### Actor-Based HTTP Client

```swift
public actor AptosHTTPClient {
    func get<T: Decodable>(url:path:params:apiType:) async throws -> T
    func post<B: Encodable, T: Decodable>(url:path:body:apiType:) async throws -> T
    func postBCS<T: Decodable>(url:path:body:contentType:apiType:) async throws -> T
}
```

- Actor isolation eliminates data races
- URLSession handles connection pooling, HTTP/2, TLS
- Automatic header management (User-Agent, API key, per-type headers)
- Snake-case key decoding via `JSONDecoder.keyDecodingStrategy`

### Configuration

```swift
public struct AptosConfig: Sendable {
    let network: Network
    let fullnodeUrl: String?
    let indexerUrl: String?
    let faucetUrl: String?
    let clientConfig: ClientConfig
    let faucetConfig: FaucetConfig

    static func mainnet() -> AptosConfig   // Chain ID 1
    static func testnet() -> AptosConfig   // Chain ID 2
    static func devnet() -> AptosConfig    // Chain ID varies
    static func localnet() -> AptosConfig  // Chain ID 4
}
```

### API Type Routing

| API Type | Default URL | Use |
|----------|-------------|-----|
| Fullnode | `https://fullnode.{network}.aptoslabs.com/v1` | REST API |
| Indexer  | `https://indexer.{network}.aptoslabs.com/v1/graphql` | GraphQL |
| Faucet   | `https://faucet.{network}.aptoslabs.com` | Test tokens |
| Pepper   | `https://api.{network}.aptoslabs.com/keyless/pepper/v0` | Keyless pepper |
| Prover   | `https://api.{network}.aptoslabs.com/keyless/prover/v0` | Keyless proofs |

---

## Concurrency Model

The SDK uses Swift 6.0 strict concurrency:

- **All types are `Sendable`**: Structs with value types are implicitly Sendable. Protocols require `Sendable` conformance.
- **`AptosHTTPClient` is an `actor`**: Serializes access to URLSession state, headers, retry logic.
- **`LRUCache` is an `actor`**: Thread-safe caching with TTL.
- **`async/await` for all network calls**: Natural integration with Swift concurrency.
- **`~Copyable` for BCS**: Serializer and Deserializer use move semantics to prevent accidental aliasing of the internal buffer.

### Sendable Conformance Strategy

```
Value types (structs, enums) → automatically Sendable
  AccountAddress, RawTransaction, ChainId, TypeTag, ...

Actors → automatically Sendable
  AptosHTTPClient, LRUCache

@unchecked Sendable → only for type-erased containers
  AnyCodable (wraps Any)

@Sendable closures → for stored function references
  SingleKeyAccount.signFunc
```

---

## Error Hierarchy

```
AptosError (top-level)
    ├─ .parse(ParseError)
    │     ├─ .invalidHex(String)
    │     ├─ .invalidAddress(String)
    │     ├─ .invalidTypeTag(String)
    │     └─ .invalidAIP80(String)
    ├─ .crypto(CryptoError)
    │     ├─ .invalidKeyLength(expected:actual:)
    │     ├─ .invalidSignatureLength(expected:actual:)
    │     ├─ .signingFailed(String)
    │     └─ .keyDerivationFailed(String)
    ├─ .serialization(SerializationError)
    │     ├─ .unexpectedEnd
    │     ├─ .remainingBytes(Int)
    │     ├─ .invalidData(String)
    │     └─ .maxLengthExceeded(Int)
    ├─ .network(NetworkError)
    │     ├─ .invalidURL(String)
    │     ├─ .invalidResponse(String)
    │     ├─ .httpError(statusCode:message:)
    │     └─ .timeout
    ├─ .api(APIError)
    │     ├─ .resourceNotFound(String)
    │     ├─ .transactionNotFound(String)
    │     ├─ .simulationFailed(String)
    │     └─ .decodingError(String)
    ├─ .transaction(TransactionError)
    │     ├─ .buildFailed(String)
    │     ├─ .simulationFailed(String)
    │     ├─ .waitTimeout(hash:)
    │     └─ .executionFailed(vmStatus:)
    └─ .keyless(KeylessError)
          ├─ .pepperServiceFailed(String)
          ├─ .proverServiceFailed(String)
          └─ .invalidConfiguration(String)
```

All errors conform to `Error`, `Sendable`, and `LocalizedError`.

---

## Differences from Other Language SDKs

| Aspect | Swift | TypeScript | Rust | Python |
|--------|-------|-----------|------|--------|
| Error handling | `throws` + typed enums | `Promise` reject | `Result<T,E>` | Exceptions |
| Concurrency | `actor` + `async/await` | `Promise` chains | `tokio::spawn` | `asyncio` |
| BCS | Custom protocols + `~Copyable` | Class-based | `serde` derive macros | Class-based |
| Crypto | CryptoKit (hardware) | tweetnacl (JS) | ed25519-dalek | PyNaCl |
| Memory | ARC + value types | Garbage collected | Ownership system | Ref counted |
| HTTP | URLSession (HTTP/2) | fetch/axios | reqwest | httpx |
| JSON | Codable (compiler) | `JSON.parse` | serde_json | pydantic |
| Type safety | Strict, no `any` | Moderate (TS) | Strict | Dynamic |
| Multi-sig | Enum + bitmap | Object + bitmap | Struct + bitmap | Class + bitmap |

### Swift-Specific Advantages

1. **Hardware-accelerated crypto**: CryptoKit on Apple Silicon uses the Secure Enclave coprocessor
2. **Copy-on-write `Data`**: Zero-cost copies until mutation
3. **Actor isolation**: No locks needed for HTTP client state
4. **Value types everywhere**: Stack allocation for most SDK types, no heap overhead
5. **`~Copyable`**: Move semantics for BCS buffer management (no accidental aliasing)
6. **Codable**: Compiler-synthesized JSON encoding/decoding
7. **Protocol-oriented**: `AptosAccount` protocol enables extensible account types

---

## Security Model

### Private Key Protection

- Private key types (`Ed25519PrivateKey`, `Secp256k1PrivateKey`, `Secp256r1PrivateKey`) do **not** conform to `CustomStringConvertible` — preventing accidental logging.
- AIP-80 format provides unambiguous serialization with scheme prefix.
- All key types validate lengths on construction (fail-fast).

### Input Validation

- `AccountAddress.fromHex()` validates length and hex format.
- BCS `Deserializer` enforces bounds checking on every read.
- ULEB128 decoding enforces `UInt32.max` ceiling.
- TypeTag parser rejects malformed Move type strings.

### Network Security

- HTTPS by default for all API endpoints.
- API key transmitted via `Authorization: Bearer` header.
- Per-API-type header separation (fullnode vs indexer vs faucet).

---

## Usage Examples

### Basic Transfer

```swift
let client = AptosClient(.testnet)
let account = try Ed25519Account.generate()

// Fund from faucet
try await client.faucet.fundAccount(address: account.accountAddress, amount: 100_000_000)

// Transfer APT
let txn = try await client.coin.transferAPT(
    from: account,
    to: try AccountAddress.fromHex("0x2"),
    amount: 1_000_000
)
```

### SingleKey Account

```swift
// New unified account type (recommended)
let account = try SingleKeyAccount.generate(scheme: .ed25519)

// Or with Secp256k1
let secpAccount = try SingleKeyAccount.generate(scheme: .secp256k1Ecdsa)
```

### Custom Transaction

```swift
let raw = try TransactionBuilder()
    .sender(account.accountAddress)
    .sequenceNumber(0)
    .payload(.entryFunction(EntryFunction(
        moduleId: MoveModuleId(address: .one, name: "aptos_account"),
        functionName: "transfer",
        typeArgs: [],
        args: [
            try bcsToBytes(AccountAddress.fromHex("0x2")),
            { var s = Serializer(); s.serializeU64(1000); return s.toBytes() }()
        ]
    )))
    .chainId(.testnet)
    .build()

let txn = SimpleTransaction(rawTransaction: raw)
let auth = try TransactionSigner.sign(transaction: .simple(txn), signer: account)
let signed = try TransactionSigner.createSignedTransaction(
    transaction: txn, senderAuthenticator: auth
)
let bcs = try signed.toBytes()
```

---

## File Structure

```
AptosSDK/
├── Package.swift
├── docs/
│   └── swift-DESIGN.md
├── Sources/AptosSDK/
│   ├── AptosClient.swift              # Unified entry point
│   ├── AptosConfig.swift              # Configuration
│   ├── Account/
│   │   ├── Account.swift              # AptosAccount protocol
│   │   ├── Ed25519Account.swift       # Legacy Ed25519
│   │   ├── SingleKeyAccount.swift     # Unified single-key
│   │   └── MultiKeyAccount.swift      # M-of-N multi-sig
│   ├── Advanced/
│   │   ├── KeylessAccount.swift       # OIDC-based keyless
│   │   ├── EphemeralKeyPair.swift     # Short-lived keys
│   │   ├── MultiAgent.swift           # Multi-agent flows
│   │   └── FeePayer.swift             # Fee payer flows
│   ├── API/
│   │   ├── GeneralAPI.swift           # Ledger info, gas, blocks
│   │   ├── AccountAPI.swift           # Account resources
│   │   ├── TransactionAPI.swift       # Submit, wait, simulate
│   │   ├── ViewAPI.swift              # View function calls
│   │   ├── FaucetAPI.swift            # Testnet faucet
│   │   ├── CoinAPI.swift              # APT operations
│   │   ├── DigitalAssetAPI.swift      # NFT operations
│   │   ├── FungibleAssetAPI.swift     # FA operations
│   │   ├── ANSAPI.swift               # Name service
│   │   ├── StakingAPI.swift           # Staking/delegation
│   │   ├── ObjectAPI.swift            # Object queries
│   │   ├── TableAPI.swift             # Table queries
│   │   ├── EventAPI.swift             # Event queries
│   │   ├── KeylessAPI.swift           # Keyless auth
│   │   └── IndexerClient.swift        # GraphQL queries
│   ├── BCS/
│   │   ├── Serializer.swift           # BCS encoder (~Copyable)
│   │   ├── Deserializer.swift         # BCS decoder (~Copyable)
│   │   └── BCSSerializable.swift      # Protocols + helpers
│   ├── Client/
│   │   └── HTTPClient.swift           # Actor-based HTTP
│   ├── Core/
│   │   ├── AccountAddress.swift       # 32-byte address
│   │   ├── Hex.swift                  # Hex utilities
│   │   ├── TypeTag.swift              # Move type tags
│   │   └── Crypto/
│   │       ├── Hashing.swift          # SHA3/SHA2, domain sep
│   │       ├── Ed25519.swift          # CryptoKit Ed25519
│   │       ├── Secp256k1.swift        # P256K secp256k1
│   │       ├── Secp256r1.swift        # CryptoKit P-256
│   │       ├── AuthenticationKey.swift # Key derivation
│   │       ├── AnyPublicKey.swift     # Type-erased keys
│   │       ├── AnySignature.swift     # Type-erased sigs
│   │       ├── MultiKey.swift         # Multi-key crypto
│   │       ├── KeylessPublicKey.swift # Keyless public key
│   │       └── PrivateKey.swift       # AIP-80 utilities
│   ├── Errors/
│   │   └── AptosError.swift           # Error hierarchy
│   ├── Transactions/
│   │   ├── RawTransaction.swift       # Raw + Signed + ChainId
│   │   ├── TransactionPayload.swift   # Payloads + EntryFunction
│   │   ├── TransactionAuthenticator.swift # Authenticators
│   │   ├── TransactionBuilder.swift   # Builder + wrappers
│   │   └── Signer.swift              # Signing utilities
│   ├── Types/
│   │   ├── APITypes.swift             # REST response types
│   │   └── Network.swift             # Network definitions
│   └── Utils/
│       ├── Cache.swift               # Actor LRU cache
│       ├── Constants.swift           # SDK constants
│       ├── Endpoints.swift           # URL resolution
│       ├── Extensions.swift          # Data/String helpers
│       └── SHA3.swift                # Keccak-f[1600]
└── Tests/AptosSDKTests/
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
    ├── Transactions/
    │   └── TransactionTests.swift
    ├── Account/
    │   └── AccountTests.swift
    └── Advanced/
        ├── MultiAgentTests.swift
        ├── FeePayerTests.swift
        └── KeylessTests.swift
```
