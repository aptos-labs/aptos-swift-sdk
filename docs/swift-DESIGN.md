# Aptos Swift SDK — Design Document

## Overview

The Aptos Swift SDK provides a comprehensive, type-safe interface for interacting with the Aptos blockchain from Apple platforms. It targets **Tier 2 (P0 + P1 Compliance)** with the [aptos-sdk-specs v1.0.0](https://github.com/aptos-labs/aptos-sdk-specs), implementing all P0 (required) and P1 (preferred) requirements.

**Key design principles:**
- **Apple-native**: CryptoKit for verification/P-256, URLSession for networking, `actor` for concurrency
- **Value-type-first**: All core types are structs (copy-on-write, stack-allocated where possible)
- **Zero-copy where feasible**: `withUnsafeBytes` for crypto operations
- **Deterministic crypto**: CTweetNaCl for RFC 8032 deterministic Ed25519 signing
- **Minimal dependencies**: Only `secp256k1.swift` (P256K) and `BigInt` as external packages

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
│                     │  + retry logic  │                             │
│                     └────────┬────────┘                             │
│                              │                                      │
│                     ┌────────┴────────┐                             │
│                     │   AptosConfig   │                             │
│                     │  Network URLs   │                             │
│                     │  Timeouts/Keys  │                             │
│                     │  RetryConfig    │                             │
│                     └─────────────────┘                             │
└─────────────────────────────────────────────────────────────────────┘
```

### Module Dependency Graph

```
AptosClient
    ├── API Layer (GeneralAPI, AccountAPI, TransactionAPI, ViewAPI, ...)
    │       ├── AptosHTTPClient (actor + exponential backoff retry)
    │       ├── AptosConfig + RetryConfig
    │       └── Types (APITypes, MoveTypes, TransactionTypes)
    ├── Transactions
    │       ├── RawTransaction / SignedTransaction
    │       ├── TransactionPayload / EntryFunction
    │       ├── TransactionAuthenticator / AccountAuthenticator
    │       ├── TransactionBuilder (fluent)
    │       └── Signer (domain-separated signing)
    ├── Accounts
    │       ├── AptosAccount (protocol + publicKeyBytes)
    │       ├── Ed25519Account (legacy scheme + fromMnemonic)
    │       ├── SingleKeyAccount (unified scheme + AnyPrivateKey)
    │       ├── MultiKeyAccount (M-of-N)
    │       └── KeylessAccount (OIDC)
    ├── Core / Crypto
    │       ├── Ed25519 (CTweetNaCl for signing, CryptoKit for verification)
    │       ├── Secp256k1 (P256K library)
    │       ├── Secp256r1 (CryptoKit P256)
    │       ├── AnyPublicKey / AnySignature (type-erased wrappers)
    │       ├── MultiKey / MultiEd25519 (multi-sig primitives)
    │       ├── AuthenticationKey (key → address derivation)
    │       ├── Mnemonic (BIP-39: generate, validate, toSeed)
    │       ├── HDKey (SLIP-0010 Ed25519 + BIP-32 Secp256k1)
    │       ├── DerivationPath (BIP-44 path parsing)
    │       ├── BIP39Wordlist (2048 English words)
    │       └── Hashing (SHA3-256, SHA2-256, domain separation)
    ├── Core / Types
    │       ├── AccountAddress (32-byte, hex encoding)
    │       ├── TypeTag / StructTag (Move type system)
    │       ├── Hex (encode/decode utilities)
    │       └── Network / Endpoints
    ├── BCS
    │       ├── Serializer (~Copyable, dynamic buffer, depth-tracked)
    │       ├── Deserializer (~Copyable, cursor-based, depth-tracked)
    │       └── BCSSerializable / BCSDeserializable protocols
    └── CTweetNaCl (C target)
            ├── tweetnacl.h (public API: seed_keypair, detached sign)
            └── tweetnacl.c (SHA-512, GF arithmetic, Ed25519)
```

---

## BCS Serialization

Binary Canonical Serialization (BCS) is the wire format for all Aptos blockchain data.

### Design

```swift
// ~Copyable struct prevents accidental aliasing of internal buffer
public struct Serializer: ~Copyable {
    private var data: Data
    private var depth: Int = 0
    static let maxDepth = 128

    mutating func serializeBool(_ value: Bool)
    mutating func serializeU8(_ value: UInt8)
    mutating func serializeU16(_ value: UInt16)
    mutating func serializeU32(_ value: UInt32)
    mutating func serializeU64(_ value: UInt64)
    mutating func serializeU128(_ value: BigUInt)
    mutating func serializeU256(_ value: BigUInt)
    mutating func serializeI128(_ value: BigInt)         // Signed 16-byte two's complement
    mutating func serializeBytes(_ value: Data)          // ULEB128 length prefix
    mutating func serializeFixedBytes(_ value: Data)     // No length prefix
    mutating func serializeStr(_ value: String)
    mutating func serializeU32AsUleb128(_ value: UInt32)
    mutating func serializeOption<T: BCSSerializable>(_ value: T?)
    mutating func serializeVector<T: BCSSerializable>(_ values: [T])

    consuming func toBytes() -> Data
}

public struct Deserializer: ~Copyable {
    private let data: Data
    private var offset: Int
    private var depth: Int = 0
    static let maxDepth = 128

    mutating func deserializeBool() throws -> Bool
    mutating func deserializeU8() throws -> UInt8
    mutating func deserializeI128() throws -> BigInt     // Signed 16-byte two's complement
    // ... matching methods
    mutating func assertFinished() throws
}
```

### Depth Tracking

Both `Serializer` and `Deserializer` maintain a `depth` counter that increments when entering nested structures (vectors, options) and decrements on exit. If the depth exceeds `maxDepth` (128), a `SerializationError.maxDepthExceeded` is thrown. This prevents stack overflow from maliciously nested inputs.

### Non-Canonical ULEB128 Rejection

The `Deserializer.deserializeUleb128()` method rejects non-canonical ULEB128 encodings. After decoding, if the final byte is `0x00` and it is not the first (and only) byte, the encoding is non-canonical (could have been represented with fewer bytes) and a `SerializationError.invalidData` error is thrown.

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
| i128     | `BigInt`  |
| bytes    | `Data`    |
| string   | `String`  |
| vector<T>| `[T]`    |
| option<T>| `T?`     |

---

## Cryptography

### Ed25519 (CTweetNaCl + CryptoKit)

```
Ed25519PrivateKey (32 bytes)
    │
    ├─ publicKey() → Ed25519PublicKey (32 bytes)    [CTweetNaCl]
    ├─ sign(Data) → Ed25519Signature (64 bytes)     [CTweetNaCl]
    ├─ toAIP80() → "ed25519-priv-0x..."
    └─ fromHex() / fromAIP80() (construction)

Ed25519PublicKey
    └─ verify(message:signature:) → Bool            [CryptoKit]
```

**Why CTweetNaCl instead of CryptoKit for signing?** Apple's CryptoKit uses _hedged_ (randomized) Ed25519 signing — it injects random nonce material for side-channel resistance. While the resulting signatures are valid, they are **non-deterministic**: signing the same message twice produces different byte sequences. This is incompatible with the Aptos SDK spec test vectors, which require exact byte-level signature matching across all SDK implementations (TypeScript, Rust, Python, Swift).

The embedded CTweetNaCl C library provides RFC 8032 **deterministic** Ed25519 signing using `crypto_sign_ed25519_seed_keypair()` and `crypto_sign_ed25519_detached()`. CryptoKit is still used for signature **verification** (`Curve25519.Signing.PublicKey.isValidSignature`), which does not have the nonce issue.

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

## BIP-39 / BIP-44 / SLIP-0010 (HD Wallet)

The SDK implements full hierarchical deterministic wallet support for deriving accounts from mnemonic phrases.

### BIP-39 Mnemonic (Mnemonic.swift)

```
Mnemonic.generate(wordCount:) → String
    │  Generates random entropy, computes SHA-256 checksum,
    │  maps to 2048-word English wordlist
    │
Mnemonic.validate(_ phrase:) → Bool
    │  Checks word count (12/15/18/21/24), all words in dictionary,
    │  and SHA-256 checksum bits match
    │
Mnemonic.toSeed(_ phrase:, passphrase:) → Data (64 bytes)
       PBKDF2-HMAC-SHA512, 2048 iterations
       Salt: "mnemonic" + passphrase
       Uses CommonCrypto.CCKeyDerivationPBKDF
```

The BIP-39 English wordlist (2048 words) is embedded as a static Swift array in `BIP39Wordlist.swift`.

### SLIP-0010 Key Derivation (HDKey.swift — Ed25519)

```
SLIP0010.derivePath(path, seed) → (key: Data, chainCode: Data)

Master key derivation:
    HMAC-SHA512(key: "ed25519 seed", data: seed)
    → left 32 bytes = master key, right 32 bytes = chain code

Child key derivation (hardened only — Ed25519 always uses hardened):
    HMAC-SHA512(key: chainCode, data: 0x00 || parentKey || index_BE)
    → left 32 bytes = child key, right 32 bytes = child chain code
```

Ed25519 only supports hardened derivation. All path indices must have the `'` suffix (e.g., `m/44'/637'/0'/0'/0'`).

### BIP-32 Key Derivation (HDKey.swift — Secp256k1)

```
BIP32.derivePath(path, seed) → (key: Data, chainCode: Data)

Master key derivation:
    HMAC-SHA512(key: "Bitcoin seed", data: seed)

Hardened child:
    HMAC-SHA512(key: chainCode, data: 0x00 || parentKey || index_BE)

Normal child:
    HMAC-SHA512(key: chainCode, data: compressedPubKey || index_BE)
```

### Derivation Path (DerivationPath.swift)

```
DerivationPath.defaultAptos = "m/44'/637'/0'/0'/0'"

    m       = master
    44'     = BIP-44 purpose (hardened)
    637'    = Aptos coin type (SLIP-44 registered)
    0'      = account index
    0'      = change (always 0 for Aptos)
    0'      = address index
```

The parser validates path format, hardened markers, and numeric indices.

### Account Integration

```swift
// Ed25519Account.fromMnemonic()
let account = try Ed25519Account.fromMnemonic(
    "abandon abandon ... about",
    path: "m/44'/637'/0'/0'/0'",     // default
    passphrase: ""                     // default
)

// Flow:
// 1. Mnemonic.toSeed(phrase, passphrase) → 64-byte seed
// 2. SLIP0010.derivePath(path, seed) → 32-byte key
// 3. Ed25519PrivateKey(data: key) → private key
// 4. privateKey.publicKey() → public key
// 5. AuthenticationKey → account address
```

---

## Account Types

### Protocol Hierarchy

```swift
public protocol AptosAccount: Sendable {
    var accountAddress: AccountAddress { get }
    var publicKeyBytes: Data { get }
    var signingScheme: SigningScheme { get }
    func sign(message: Data) throws -> AnySignature
    func signWithAuthenticator(message: Data) throws -> AccountAuthenticator
    func authenticationKey() throws -> AuthenticationKey
}
```

### Account Types

| Type | Scheme | Keys | Use Case |
|------|--------|------|----------|
| `Ed25519Account` | Ed25519 (0) | Ed25519 only | Legacy accounts, mnemonic derivation |
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

AnyPrivateKey (enum)
    ├─ .ed25519(Ed25519PrivateKey)
    ├─ .secp256k1(Secp256k1PrivateKey)
    └─ .secp256r1(Secp256r1PrivateKey)
```

`AnyPrivateKey` is exposed on `SingleKeyAccount` so the private key is accessible for export, not hidden behind a signing closure.

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
    .expirationTimestampSecs(now + 600s)       Default (spec-compliant)
    .chainId(.testnet)
    .build()
    → RawTransaction
```

Default transaction expiry is **600 seconds** (10 minutes) per the Aptos SDK spec.

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

### Actor-Based HTTP Client with Retry

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

### Retry Strategy

The HTTP client implements exponential backoff retry for transient failures:

```
Retryable conditions:
    - Network errors (URLError)
    - Timeout errors
    - HTTP 429 (Too Many Requests)
    - HTTP 5xx (Server errors)

Backoff schedule (defaults):
    Attempt 1: immediate
    Retry 1:   200ms wait
    Retry 2:   400ms wait
    Retry 3:   800ms wait

On 429 responses:
    Respect Retry-After header if present, otherwise use backoff schedule

After all retries exhausted:
    Throw AptosError.network(.retryExhausted(...))
```

### Configuration

```swift
public struct AptosConfig: Sendable {
    let network: Network
    let fullnodeURL: String?
    let indexerURL: String?
    let faucetURL: String?
    let pepperURL: String?
    let proverURL: String?
    let clientConfig: ClientConfig
    let fullnodeHeaders: [String: String]
    let indexerHeaders: [String: String]
    let faucetConfig: FaucetConfig
    let transactionConfig: TransactionGenerationConfig
    let retryConfig: RetryConfig
}

public struct RetryConfig: Sendable {
    var maxRetries: Int = 3
    var initialBackoffMs: UInt64 = 200
    var backoffMultiplier: Double = 2.0
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
    │     ├─ .invalidStructTag(String)
    │     ├─ .invalidModuleId(String)
    │     ├─ .invalidMoveFunction(String)
    │     ├─ .invalidDerivationPath(String)
    │     ├─ .invalidMnemonic(String)
    │     └─ .invalidAIP80(String)
    ├─ .crypto(CryptoError)
    │     ├─ .invalidKeyLength(expected:actual:)
    │     ├─ .invalidSignatureLength(expected:actual:)
    │     ├─ .signingFailed(String)
    │     ├─ .keyDerivationFailed(String)
    │     └─ .invalidPrivateKey(String)
    ├─ .serialization(SerializationError)
    │     ├─ .unexpectedEnd
    │     ├─ .remainingBytes(Int)
    │     ├─ .invalidData(String)
    │     ├─ .maxLengthExceeded(Int)
    │     └─ .maxDepthExceeded(Int)
    ├─ .network(NetworkError)
    │     ├─ .invalidURL(String)
    │     ├─ .invalidResponse(String)
    │     ├─ .httpError(statusCode:message:)
    │     ├─ .retryExhausted(String)
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
    ├─ .keyless(KeylessError)
    │     ├─ .pepperServiceFailed(String)
    │     ├─ .proverServiceFailed(String)
    │     └─ .invalidConfiguration(String)
    ├─ .unauthorized(String)           // HTTP 401
    ├─ .rateLimited(String)            // HTTP 429
    ├─ .internalError(String)          // HTTP 5xx
    ├─ .invalidArgument(String)
    ├─ .invalidState(String)
    ├─ .notFound(String)
    ├─ .timeout(String)
    └─ .unknown(String)
```

All errors conform to `Error`, `Sendable`, and `LocalizedError`.

---

## Differences from Other Language SDKs

| Aspect | Swift | TypeScript | Rust | Python |
|--------|-------|-----------|------|--------|
| Error handling | `throws` + typed enums | `Promise` reject | `Result<T,E>` | Exceptions |
| Concurrency | `actor` + `async/await` | `Promise` chains | `tokio::spawn` | `asyncio` |
| BCS | Custom protocols + `~Copyable` | Class-based | `serde` derive macros | Class-based |
| Ed25519 signing | CTweetNaCl (C) | tweetnacl (JS) | ed25519-dalek | PyNaCl |
| Ed25519 verify | CryptoKit (hardware) | tweetnacl (JS) | ed25519-dalek | PyNaCl |
| Memory | ARC + value types | Garbage collected | Ownership system | Ref counted |
| HTTP | URLSession (HTTP/2) + retry | fetch/axios | reqwest | httpx |
| JSON | Codable (compiler) | `JSON.parse` | serde_json | pydantic |
| Type safety | Strict, no `any` | Moderate (TS) | Strict | Dynamic |
| HD Wallet | CommonCrypto + CryptoKit | @scure/bip39 | bip39 crate | mnemonic |
| Multi-sig | Enum + bitmap | Object + bitmap | Struct + bitmap | Class + bitmap |

### Swift-Specific Design Decisions

1. **CTweetNaCl for deterministic Ed25519**: Apple's CryptoKit uses hedged (randomized) Ed25519 signing. We embed a minimal TweetNaCl-based C library for RFC 8032 deterministic signing, while still using CryptoKit for verification (which benefits from hardware acceleration on Apple Silicon).

2. **CommonCrypto for PBKDF2**: BIP-39 seed derivation uses `CCKeyDerivationPBKDF` from Apple's CommonCrypto, which is heavily optimized and available on all Apple platforms without additional dependencies.

3. **CryptoKit HMAC-SHA512 for HD derivation**: SLIP-0010 and BIP-32 key derivation uses CryptoKit's `HMAC<SHA512>` implementation, which is hardware-accelerated.

4. **Copy-on-write `Data`**: Zero-cost copies until mutation.

5. **Actor isolation**: No locks needed for HTTP client state.

6. **Value types everywhere**: Stack allocation for most SDK types, no heap overhead.

7. **`~Copyable`**: Move semantics for BCS buffer management (no accidental aliasing).

8. **Codable**: Compiler-synthesized JSON encoding/decoding.

9. **Protocol-oriented**: `AptosAccount` protocol enables extensible account types.

---

## Security Model

### Private Key Protection

- Private key types (`Ed25519PrivateKey`, `Secp256k1PrivateKey`, `Secp256r1PrivateKey`) do **not** conform to `CustomStringConvertible` — preventing accidental logging.
- AIP-80 format provides unambiguous serialization with scheme prefix.
- All key types validate lengths on construction (fail-fast).
- `SingleKeyAccount` exposes the private key via `AnyPrivateKey` enum for controlled access.

### Input Validation

- `AccountAddress.fromHex()` validates length and hex format.
- BCS `Deserializer` enforces bounds checking on every read.
- BCS depth tracking enforces `maxDepth = 128` to prevent stack overflow.
- ULEB128 decoding enforces `UInt32.max` ceiling and rejects non-canonical encodings.
- TypeTag parser rejects malformed Move type strings.
- Mnemonic validation checks word count, dictionary membership, and SHA-256 checksum.
- Derivation path parsing validates format and hardened markers.

### Network Security

- HTTPS by default for all API endpoints.
- API key transmitted via `Authorization: Bearer` header.
- Per-API-type header separation (fullnode vs indexer vs faucet).
- Exponential backoff retry prevents thundering herd on transient failures.
- `Retry-After` header is respected to avoid rate limit violations.

---

## Test Vectors

The SDK includes ~270 deterministic test cases across 21 test suites. Seven JSON test vector files from the [aptos-sdk-specs](https://github.com/aptos-labs/aptos-sdk-specs) test suite ensure cross-implementation compatibility:

| File | Test Cases | Coverage |
|------|-----------|----------|
| `addresses.json` | ~23 | Address parsing, constants, invalid inputs, BCS |
| `bcs.json` | ~55 | All primitive types, ULEB128, vectors, options, structs |
| `signatures.json` | ~21 | Ed25519/Secp256k1 key derivation, signing, verification, hashing |
| `type-tags.json` | ~35 | Primitive/vector/struct types, module IDs, invalid strings |
| `transactions.json` | ~34 | Raw transaction BCS, entry function encoding, domain prefixes |
| `mnemonics.json` | ~20 | BIP-39 seed, SLIP-0010 derivation, auth key, validation |
| `multi-sig.json` | ~12 | Multi-Ed25519 auth key, bitmap encoding, threshold cases |

The `TestVectorLoader` utility loads these JSON files at test time via `Bundle.module` resource access.

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

### HD Wallet Account

```swift
// Generate a new mnemonic and derive accounts
let mnemonic = Mnemonic.generate(wordCount: .twelve)
let account0 = try Ed25519Account.fromMnemonic(mnemonic, path: "m/44'/637'/0'/0'/0'")
let account1 = try Ed25519Account.fromMnemonic(mnemonic, path: "m/44'/637'/0'/0'/1'")
```

### Create and Fund Account (Convenience)

```swift
let client = AptosClient(.testnet)
let account = try await client.faucet.createAndFundAccount(amount: 100_000_000)
print("Funded new account: \(account.accountAddress)")
```

### SingleKey Account

```swift
// New unified account type (recommended)
let account = try SingleKeyAccount.generate(scheme: .ed25519)

// Access the private key for export
if case .ed25519(let privKey) = account.privateKey {
    let aip80 = privKey.toAIP80()
}

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
aptos-swift-sdk/
├── Package.swift
├── Makefile
├── .swiftformat
├── .swiftlint.yml
├── docs/
│   └── swift-DESIGN.md
├── Sources/
│   ├── CTweetNaCl/                       # Embedded C library
│   │   ├── include/tweetnacl.h           # Public Ed25519 API
│   │   └── tweetnacl.c                   # Deterministic Ed25519 (RFC 8032)
│   └── AptosSDK/
│       ├── AptosClient.swift             # Unified entry point
│       ├── AptosConfig.swift             # Configuration + RetryConfig
│       ├── Account/
│       │   ├── Account.swift             # AptosAccount protocol + publicKeyBytes
│       │   ├── Ed25519Account.swift      # Legacy Ed25519 + fromMnemonic()
│       │   ├── SingleKeyAccount.swift    # Unified single-key + AnyPrivateKey
│       │   └── MultiKeyAccount.swift     # M-of-N multi-sig
│       ├── Advanced/
│       │   ├── KeylessAccount.swift      # OIDC-based keyless
│       │   ├── EphemeralKeyPair.swift    # Short-lived keys
│       │   ├── MultiAgent.swift          # Multi-agent flows
│       │   └── FeePayer.swift            # Fee payer flows
│       ├── API/
│       │   ├── GeneralAPI.swift          # Ledger info, gas, blocks
│       │   ├── AccountAPI.swift          # Account resources
│       │   ├── TransactionAPI.swift      # Submit, wait, simulate
│       │   ├── ViewAPI.swift             # View function calls
│       │   ├── FaucetAPI.swift           # Testnet faucet + createAndFundAccount()
│       │   ├── CoinAPI.swift             # APT operations
│       │   ├── DigitalAssetAPI.swift     # NFT operations
│       │   ├── FungibleAssetAPI.swift    # FA operations
│       │   ├── ANSAPI.swift              # Name service
│       │   ├── StakingAPI.swift          # Staking/delegation
│       │   ├── ObjectAPI.swift           # Object queries
│       │   ├── TableAPI.swift            # Table queries
│       │   ├── EventAPI.swift            # Event queries
│       │   ├── KeylessAPI.swift          # Keyless auth
│       │   └── IndexerClient.swift       # GraphQL queries
│       ├── BCS/
│       │   ├── Serializer.swift          # BCS encoder (~Copyable, depth-tracked)
│       │   ├── Deserializer.swift        # BCS decoder (~Copyable, depth-tracked)
│       │   └── BCSSerializable.swift     # Protocols + helpers
│       ├── Client/
│       │   └── HTTPClient.swift          # Actor-based HTTP with retry
│       ├── Core/
│       │   ├── AccountAddress.swift      # 32-byte address
│       │   ├── Hex.swift                 # Hex utilities
│       │   ├── TypeTag.swift             # Move type tags
│       │   └── Crypto/
│       │       ├── Hashing.swift         # SHA3/SHA2, domain separation
│       │       ├── Ed25519.swift         # CTweetNaCl signing + CryptoKit verify
│       │       ├── Secp256k1.swift       # P256K secp256k1
│       │       ├── Secp256r1.swift       # CryptoKit P-256
│       │       ├── AuthenticationKey.swift # Key derivation
│       │       ├── AnyPublicKey.swift    # Type-erased keys
│       │       ├── AnySignature.swift    # Type-erased sigs
│       │       ├── MultiKey.swift        # Multi-key crypto
│       │       ├── KeylessPublicKey.swift # Keyless public key
│       │       ├── PrivateKey.swift       # AIP-80 utilities
│       │       ├── Mnemonic.swift        # BIP-39 implementation
│       │       ├── HDKey.swift           # SLIP-0010 + BIP-32 derivation
│       │       ├── DerivationPath.swift  # BIP-44 path parsing
│       │       └── BIP39Wordlist.swift   # 2048-word English wordlist
│       ├── Errors/
│       │   └── AptosError.swift          # Full error hierarchy
│       ├── Transactions/
│       │   ├── RawTransaction.swift      # Raw + Signed + ChainId
│       │   ├── TransactionPayload.swift  # Payloads + EntryFunction
│       │   ├── TransactionAuthenticator.swift # Authenticators
│       │   ├── TransactionBuilder.swift  # Builder + wrappers
│       │   └── Signer.swift             # Signing utilities
│       ├── Types/
│       │   ├── APITypes.swift            # REST response types
│       │   └── Network.swift            # Network definitions
│       └── Utils/
│           ├── Cache.swift              # Actor LRU cache
│           ├── Constants.swift          # SDK constants
│           ├── Endpoints.swift          # URL resolution
│           ├── Extensions.swift         # Data/String helpers
│           └── SHA3.swift               # Keccak-f[1600]
└── Tests/AptosSDKTests/
    ├── TestVectorLoader.swift           # JSON loader + hex helpers
    ├── TestVectors/                     # Spec test vector JSON files (7 files)
    │   ├── addresses.json
    │   ├── bcs.json
    │   ├── signatures.json
    │   ├── type-tags.json
    │   ├── transactions.json
    │   ├── mnemonics.json
    │   └── multi-sig.json
    ├── AddressVectorTests.swift
    ├── BCSVectorTests.swift
    ├── SignatureVectorTests.swift
    ├── TypeTagVectorTests.swift
    ├── TransactionVectorTests.swift
    ├── MnemonicVectorTests.swift
    ├── MultiSigVectorTests.swift
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
