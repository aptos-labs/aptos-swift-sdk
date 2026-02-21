# Aptos Swift SDK

A comprehensive, type-safe Swift SDK for the [Aptos](https://aptoslabs.com) blockchain, targeting **Tier 2 (P0 + P1 Compliance)** with the [aptos-sdk-specs](https://github.com/aptos-labs/aptos-sdk-specs) v1.0.0.

## Requirements

| Platform | Minimum |
|----------|---------|
| iOS      | 17.0    |
| macOS    | 14.0    |
| watchOS  | 10.0    |
| tvOS     | 17.0    |
| Swift    | 6.0     |

## Installation

### Swift Package Manager

Add the following to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/aptos-labs/aptos-swift-sdk.git", from: "1.0.0"),
]
```

Then add `AptosSDK` as a dependency of your target:

```swift
.target(
    name: "YourApp",
    dependencies: ["AptosSDK"]
),
```

### Xcode

1. File > Add Package Dependencies...
2. Enter the repository URL
3. Select "Up to Next Major Version" and enter `1.0.0`

## Quick Start

```swift
import AptosSDK

// Create a client
let client = AptosClient(.testnet)

// Generate an account
let account = try Ed25519Account.generate()
print("Address: \(account.accountAddress)")

// Fund from faucet (testnet only)
try await client.faucet.fundAccount(
    address: account.accountAddress,
    amount: 100_000_000 // 1 APT
)

// Check balance
let balance = try await client.coin.getBalance(address: account.accountAddress)
print("Balance: \(balance) octas")

// Transfer APT
let txn = try await client.coin.transferAPT(
    from: account,
    to: try AccountAddress.fromHex("0x2"),
    amount: 1_000_000
)
```

## Core Concepts

### Accounts

The SDK supports multiple account types through the `AptosAccount` protocol:

```swift
// Legacy Ed25519 (compatible with all wallets)
let legacy = try Ed25519Account.generate()

// Unified SingleKey (recommended for new accounts)
let unified = try SingleKeyAccount.generate(scheme: .ed25519)

// Secp256k1 (Bitcoin-compatible)
let secp = try SingleKeyAccount.generate(scheme: .secp256k1Ecdsa)

// Multi-key M-of-N (multi-sig)
let multiKey = try MultiKey(
    publicKeys: [.ed25519(key1), .secp256k1(key2), .ed25519(key3)],
    signaturesRequired: 2
)
let multiAccount = try MultiKeyAccount(
    multiKey: multiKey,
    signers: [signer1, signer2],
    signerIndices: [0, 1]
)
```

### HD Wallet (BIP-39 / BIP-44)

The SDK includes full mnemonic-based HD wallet support:

```swift
// Generate a new 12-word mnemonic
let mnemonic = Mnemonic.generate(wordCount: .twelve)

// Derive an Ed25519 account from a mnemonic (default Aptos path: m/44'/637'/0'/0'/0')
let account = try Ed25519Account.fromMnemonic(mnemonic)

// Derive with a custom path or passphrase
let account1 = try Ed25519Account.fromMnemonic(mnemonic, path: "m/44'/637'/0'/0'/1'")
let accountWithPass = try Ed25519Account.fromMnemonic(mnemonic, passphrase: "my-passphrase")

// Validate a mnemonic phrase
if Mnemonic.validate(mnemonic) {
    print("Valid BIP-39 mnemonic")
}

// Derive a BIP-39 seed directly
let seed = try Mnemonic.toSeed(mnemonic, passphrase: "")
```

Supported word counts: 12, 15, 18, 21, 24. Key derivation uses SLIP-0010 (Ed25519) and BIP-32 (Secp256k1) with PBKDF2-HMAC-SHA512 for seed generation (2048 iterations per BIP-39).

### Private Key Formats

All keys support AIP-80 serialization for unambiguous storage:

```swift
// Create from hex
let key = try Ed25519PrivateKey.fromHex("0x...")

// Create from AIP-80 format
let key = try Ed25519PrivateKey.fromAIP80("ed25519-priv-0x...")

// Export to AIP-80
let aip80 = key.toAIP80() // "ed25519-priv-0x..."
```

### Transactions

#### Simple Transfer

```swift
let client = AptosClient(.testnet)

let txn = try await client.coin.transferAPT(
    from: account,
    to: recipientAddress,
    amount: 1_000_000
)
```

#### Custom Entry Function

```swift
let payload = TransactionPayload.entryFunction(EntryFunction(
    moduleId: MoveModuleId(address: .one, name: "aptos_account"),
    functionName: "transfer",
    typeArgs: [],
    args: [
        try bcsToBytes(recipientAddress),
        { var s = Serializer(); s.serializeU64(amount); return s.toBytes() }(),
    ]
))

let raw = try TransactionBuilder()
    .sender(account.accountAddress)
    .sequenceNumber(seqNum)
    .payload(payload)
    .chainId(.testnet)
    .build()

let txn = SimpleTransaction(rawTransaction: raw)
let auth = try TransactionSigner.sign(transaction: .simple(txn), signer: account)
let signed = try TransactionSigner.createSignedTransaction(
    transaction: txn, senderAuthenticator: auth
)
```

#### Fee-Payer (Sponsored) Transactions

```swift
let signed = try FeePayerUtils.signFeePayerTransaction(
    transaction: FeePayerUtils.buildFeePayerTransaction(
        rawTransaction: raw,
        feePayerAddress: sponsor.accountAddress
    ),
    sender: sender,
    feePayer: sponsor
)
```

#### Multi-Agent Transactions

```swift
let signed = try MultiAgentUtils.signMultiAgentTransaction(
    transaction: MultiAgentUtils.buildMultiAgentTransaction(
        rawTransaction: raw,
        secondarySignerAddresses: [secondary.accountAddress]
    ),
    sender: primary,
    secondarySigners: [secondary]
)
```

### View Functions

```swift
let result: [AnyCodable] = try await client.view.view(
    function: "0x1::coin::balance",
    typeArguments: ["0x1::aptos_coin::AptosCoin"],
    arguments: [account.accountAddress.toHex()]
)
```

### BCS Serialization

The SDK uses Binary Canonical Serialization (BCS) for all on-chain data:

```swift
// Serialize
var serializer = Serializer()
serializer.serializeU64(42)
try address.serialize(to: &serializer)
let bytes = serializer.toBytes()

// Deserialize
var deserializer = Deserializer(data: bytes)
let value = try deserializer.deserializeU64()
let addr = try AccountAddress.deserialize(from: &deserializer)

// Convenience helpers
let encoded = try bcsToBytes(myValue)
let decoded = try bcsFromBytes(MyType.self, encoded)
```

### Configuration

```swift
// Preset networks
let mainnet = AptosClient(.mainnet)
let testnet = AptosClient(.testnet)
let devnet  = AptosClient(.devnet)
let local   = AptosClient(.localnet)

// Custom configuration with retry and timeout tuning
let config = AptosConfig(
    network: .custom(name: "my-network", chainId: 42),
    fullnodeURL: "https://my-node.example.com/v1",
    indexerURL: "https://my-indexer.example.com/v1/graphql",
    clientConfig: ClientConfig(
        apiKey: "my-api-key",
        timeoutInterval: 30
    ),
    retryConfig: RetryConfig(
        maxRetries: 5,
        initialBackoffMs: 300,
        backoffMultiplier: 2.0
    )
)
let client = AptosClient(config)
```

The HTTP client automatically retries transient failures (HTTP 429, 5xx, network errors) with exponential backoff. Default: 3 retries starting at 200ms. The `Retry-After` header is respected on 429 responses.

## API Reference

`AptosClient` composes all domain APIs:

| Property | Type | Description |
|----------|------|-------------|
| `general` | `GeneralAPI` | Ledger info, gas estimation, blocks |
| `account` | `AccountAPI` | Account data, resources, modules |
| `transaction` | `TransactionAPI` | Build, sign, submit, simulate, wait |
| `view` | `ViewAPI` | View function execution |
| `coin` | `CoinAPI` | APT transfer and balance |
| `faucet` | `FaucetAPI` | Testnet faucet funding |
| `digitalAsset` | `DigitalAssetAPI` | NFT collections and tokens |
| `fungibleAsset` | `FungibleAssetAPI` | Fungible asset operations |
| `ans` | `ANSAPI` | Aptos Name Service lookups |
| `staking` | `StakingAPI` | Staking and delegation pools |
| `object` | `ObjectAPI` | Move object queries |
| `table` | `TableAPI` | Table state queries |
| `event` | `EventAPI` | Event queries |
| `keyless` | `KeylessAPI` | Keyless auth (pepper/prover) |
| `indexer` | `IndexerClient` | GraphQL indexer queries |

## Architecture

The SDK is organized into layers:

```
AptosClient (unified entry point)
  ├── API Layer (15 domain APIs)
  ├── Transactions (builder, signer, authenticators)
  ├── Accounts (Ed25519, SingleKey, MultiKey, Keyless)
  ├── Core/Crypto (keys, signatures, hashing, mnemonic, HD derivation)
  ├── BCS (serializer, deserializer, depth-tracked)
  ├── Networking (actor-based HTTP client with retry)
  └── CTweetNaCl (embedded C library for deterministic Ed25519)
```

See [docs/swift-DESIGN.md](docs/swift-DESIGN.md) for the full design document.

## Development

### Prerequisites

```bash
# Required
brew install swiftformat swiftlint
```

### Building

```bash
swift build
```

### Testing

```bash
swift test
```

The test suite includes ~270 tests across 21 suites, including deterministic test vectors from the [aptos-sdk-specs](https://github.com/aptos-labs/aptos-sdk-specs) covering addresses, BCS, signatures, type tags, transactions, mnemonics, and multi-sig.

### Formatting

The project uses [SwiftFormat](https://github.com/nicklockwood/SwiftFormat) for consistent code style. Configuration is in `.swiftformat`.

```bash
# Format all source files
make format

# Check without modifying (CI mode)
make format-check
```

Key formatting rules:
- 4-space indentation (no tabs)
- 120-character line length maximum
- Sorted imports with `@testable` at the bottom
- Trailing commas in multi-line collections
- Remove redundant `self`, `return`, `init`, `Void`
- K&R brace style (`} else {` on same line)
- `guard else` on next line

### Linting

The project uses [SwiftLint](https://github.com/realm/SwiftLint) for static analysis. Configuration is in `.swiftlint.yml`.

```bash
# Lint all source and test files
make lint

# Auto-fix what can be fixed
make lint-fix
```

Key lint rules enforced:
- `force_unwrapping` — no `!` force unwraps
- `cyclomatic_complexity` — max 15 (warning), 25 (error)
- `function_body_length` — max 60 lines (warning), 100 (error)
- `identifier_name` — minimum 2 characters (with exceptions for loop vars)
- `line_length` — 120 warning, 200 error
- 50+ opt-in rules for code quality (see `.swiftlint.yml`)

### All Checks (CI)

```bash
make ci
```

This runs build, test, format-check, and lint in sequence. The same checks run in GitHub Actions on every push and PR to `main`.

Or run individually:

```bash
make build
make test
make format-check
make lint
```

## Best Practices

### Error Handling

All SDK errors are strongly typed via `AptosError`:

```swift
do {
    let balance = try await client.coin.getBalance(address: address)
} catch let error as AptosError {
    switch error {
    case .network(.httpError(let statusCode, let message)):
        print("HTTP \(statusCode): \(message)")
    case .api(.resourceNotFound(let msg)):
        print("Not found: \(msg)")
    case .transaction(.waitTimeout(let hash)):
        print("Transaction \(hash) timed out")
    case .unauthorized(let msg):
        print("Auth failed: \(msg)")       // HTTP 401
    case .rateLimited(let msg):
        print("Rate limited: \(msg)")       // HTTP 429
    case .internalError(let msg):
        print("Server error: \(msg)")       // HTTP 5xx
    default:
        print("Error: \(error.localizedDescription)")
    }
}
```

### Concurrency

The SDK is fully compatible with Swift 6.0 strict concurrency:

- All types are `Sendable`
- Network calls use `async/await`
- The HTTP client is an `actor` (thread-safe by construction)
- No locks or manual synchronization needed

```swift
// Safe to call from any actor/task
async let balance = client.coin.getBalance(address: addr1)
async let info = client.general.getLedgerInfo()
let (b, i) = try await (balance, info)
```

### Security

- **Never log private keys.** Private key types intentionally do not conform to `CustomStringConvertible`.
- **Use AIP-80 format** for key serialization — it includes the scheme prefix for unambiguous parsing.
- **Validate addresses** using `AccountAddress.fromHex()` which checks length and format.
- **HTTPS only** — all default API endpoints use HTTPS.
- **Deterministic signing** — Ed25519 signatures use a deterministic nonce (RFC 8032) via the embedded CTweetNaCl library, ensuring reproducible signatures across platforms.
- **BCS depth limits** — serialization/deserialization enforce a max nesting depth of 128 to prevent stack overflow from malicious inputs.
- **Non-canonical ULEB128 rejection** — the BCS deserializer rejects non-canonical ULEB128 encodings (e.g., `0x80 0x00` for the value 0), preventing ambiguity attacks.

### Performance

- **Deterministic Ed25519 via CTweetNaCl** — embedded C implementation provides RFC 8032 deterministic signing while CryptoKit handles verification with hardware acceleration.
- **Value types** — most SDK types are structs (stack-allocated, no heap overhead).
- **Copy-on-write `Data`** — BCS buffers use Swift's COW `Data` type for zero-cost copies.
- **Actor-based networking** — connection pooling via URLSession, HTTP/2 multiplexing.
- **Exponential backoff retry** — transient failures are retried automatically without wasting resources.
- **PBKDF2 via CommonCrypto** — mnemonic seed derivation uses Apple's optimized C implementation.

## Dependencies

| Package | Purpose |
|---------|---------|
| [secp256k1.swift](https://github.com/nicklockwood/secp256k1.swift) (P256K) | Secp256k1 ECDSA signing |
| [BigInt](https://github.com/attaswift/BigInt) | U128/U256/I128 arithmetic for BCS |
| CTweetNaCl (embedded) | Deterministic Ed25519 signing (RFC 8032) |

Apple frameworks used: `CryptoKit` (Ed25519 verification, P-256, HMAC-SHA512), `CommonCrypto` (PBKDF2-HMAC-SHA512 for BIP-39), `Foundation` (networking, data types).

## License

Apache 2.0
