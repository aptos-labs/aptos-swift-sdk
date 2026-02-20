# Aptos Swift SDK

A comprehensive, type-safe Swift SDK for the [Aptos](https://aptoslabs.com) blockchain, targeting **Tier 3 (Full Compliance)** with the [aptos-sdk-specs](https://github.com/aptos-labs/aptos-sdk-specs) v1.0.0.

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

// Custom configuration
let config = AptosConfig(
    network: .custom(name: "my-network", chainId: 42),
    fullnodeUrl: "https://my-node.example.com/v1",
    indexerUrl: "https://my-indexer.example.com/v1/graphql",
    clientConfig: ClientConfig(
        apiKey: "my-api-key",
        timeoutInterval: 30
    )
)
let client = AptosClient(config)
```

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
  ├── Core/Crypto (keys, signatures, hashing)
  ├── BCS (serializer, deserializer)
  └── Networking (actor-based HTTP client)
```

See [docs/swift-DESIGN.md](docs/swift-DESIGN.md) for the full design document.

## Development

### Building

```bash
swift build
```

### Testing

```bash
swift test
```

### Formatting

The project uses [SwiftFormat](https://github.com/nicklockwood/SwiftFormat) for consistent code style:

```bash
# Install
brew install swiftformat

# Format all source files
swiftformat Sources/ Tests/

# Check without modifying (CI mode)
swiftformat --lint Sources/ Tests/
```

### Linting

The project uses [SwiftLint](https://github.com/realm/SwiftLint) for static analysis:

```bash
# Install
brew install swiftlint

# Lint
swiftlint lint Sources/ Tests/

# Auto-fix
swiftlint lint --fix Sources/ Tests/
```

### All Checks (CI)

```bash
make ci
```

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

### Performance

- **CryptoKit hardware acceleration** — Ed25519 and P-256 operations use Apple's Secure Enclave coprocessor on supported hardware.
- **Value types** — Most SDK types are structs (stack-allocated, no heap overhead).
- **Copy-on-write `Data`** — BCS buffers use Swift's COW `Data` type for zero-cost copies.
- **Actor-based networking** — Connection pooling via URLSession, HTTP/2 multiplexing.

## License

Apache 2.0
