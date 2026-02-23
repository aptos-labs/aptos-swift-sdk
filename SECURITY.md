# Security Guide

Security best practices for applications built with the Aptos Swift SDK.

## Private Key Management

### Never log or display private keys

Private key types (`Ed25519PrivateKey`, `Secp256k1PrivateKey`, `Secp256r1PrivateKey`) intentionally redact their contents in `String(describing:)` and `print()`. Do not circumvent this by accessing `.data` for logging purposes.

```swift
// SAFE: redacted output
print(privateKey) // "Ed25519PrivateKey(<redacted>)"

// DANGEROUS: never do this in production
print(privateKey.data.hexString) // exposes raw key bytes
```

### Use AIP-80 format for serialization

When storing or transmitting private keys, use the AIP-80 format which includes the key scheme prefix. This prevents ambiguity when importing keys later.

```swift
let aip80 = privateKey.toAIP80() // "ed25519-priv-0x..."

// Later, parse unambiguously:
let (variant, data) = try PrivateKeyUtils.parseAIP80(aip80)
```

### Zeroize keys when done

Call `zeroize()` on private key instances when they are no longer needed to overwrite the in-memory buffer with zeros. Note that Swift value-type copies cannot be auto-zeroized; only the specific instance is cleared.

```swift
var key = try Ed25519PrivateKey.fromHex("0x...")
defer { key.zeroize() }
// ... use key ...
```

### Store keys in the Keychain

For iOS/macOS apps, store private keys in the system Keychain rather than `UserDefaults`, files, or Core Data. The Keychain provides hardware-backed encryption on devices with a Secure Enclave.

### Mnemonic phrase handling

- Display mnemonic phrases only during initial generation, and prompt the user to write them down.
- Never store mnemonic phrases in plain text on disk.
- Validate mnemonics with `Mnemonic.validate()` before deriving keys.
- Use a passphrase for additional protection when appropriate.

## Address Validation

Always validate addresses using `AccountAddress.fromHex()`, which checks both length and hex format. Never construct addresses from unvalidated user input.

```swift
// SAFE: validates format and length
let address = try AccountAddress.fromHex(userInput)

// DANGEROUS: no validation
let unsafeAddress = AccountAddress(bytes: Data(hex: userInput))
```

## Network Security

### HTTPS only

All default API endpoints use HTTPS. When configuring custom endpoints, always use HTTPS in production.

```swift
// GOOD: HTTPS
let config = AptosConfig(
    network: .custom(name: "prod", chainId: 42),
    fullnodeURL: "https://my-node.example.com/v1"
)

// BAD: HTTP in production (acceptable only for local development)
let config = AptosConfig(
    network: .local,
    fullnodeURL: "http://127.0.0.1:8080/v1"
)
```

### API key protection

API keys are sent via the `Authorization: Bearer` header. Keep them out of source control and client-side bundles:

- Use environment variables or a secrets manager for API keys.
- Rotate keys regularly.
- Use separate keys for development and production.

### Rate limiting awareness

The SDK automatically retries HTTP 429 (Too Many Requests) responses with exponential backoff and respects the `Retry-After` header. For high-throughput applications:

- Use an API key to get higher rate limits.
- Batch operations where possible.
- Monitor for `AptosError.rateLimited` errors in your error handling.

## Transaction Security

### Verify transaction parameters

Before signing, verify transaction parameters match your intent:

```swift
let raw = try TransactionBuilder()
    .sender(account.accountAddress)
    .sequenceNumber(seqNum)
    .payload(payload)
    .maxGasAmount(200_000)      // Set explicit limits
    .gasUnitPrice(100)          // Verify gas price
    .chainId(.mainnet)          // Confirm target chain
    .build()
```

### Chain ID verification

Always specify the correct chain ID to prevent cross-chain replay attacks. The SDK provides presets (`.mainnet`, `.testnet`, `.devnet`, `.local`) and validates them during transaction building.

### Transaction simulation

Use `TransactionAPI.simulate()` before submitting transactions to verify the expected outcome without spending gas:

```swift
let results = try await client.transaction.simulate(
    transaction: .simple(txn),
    signerPublicKey: account.publicKey
)
// Check results before submitting
```

### Fee-payer awareness

When using sponsored transactions, verify the fee payer address matches the expected sponsor. The SDK validates consistency between `feePayerAddress` and the provided `feePayerAuthenticator`.

## BCS Serialization Safety

### Depth limits

The BCS serializer and deserializer enforce a maximum nesting depth of 128 to prevent stack overflow from maliciously nested data structures. Do not increase this limit.

### Non-canonical ULEB128 rejection

The deserializer rejects non-canonical ULEB128 encodings (e.g., `0x80 0x00` for the value 0). This prevents ambiguity attacks where multiple byte sequences decode to the same value.

### Length limits

Byte array serialization is capped at 10 MB (`Serializer.maxLength`). This prevents memory exhaustion from maliciously large payloads during deserialization.

## Deterministic Signing

The SDK uses RFC 8032 deterministic Ed25519 signing (via the embedded CTweetNaCl library) rather than Apple's CryptoKit hedged signing. This ensures:

- Identical signatures for identical inputs across all platforms.
- No dependency on random number generation during signing.
- Compatibility with the Aptos SDK spec test vectors.

CryptoKit is still used for Ed25519 signature **verification**, which benefits from hardware acceleration.

## Concurrency Safety

The SDK is built for Swift 6.0 strict concurrency:

- All public types are `Sendable`.
- `AptosHTTPClient` and `LRUCache` are actors (thread-safe by construction).
- No manual locks or synchronization are needed.

You can safely call SDK methods from any actor or task without data race concerns.

## Reporting Vulnerabilities

If you discover a security vulnerability, please report it responsibly:

1. **Do not** open a public GitHub issue.
2. Email security findings to the Aptos Labs security team.
3. Include steps to reproduce, affected versions, and potential impact.

See the [Aptos Security Policy](https://github.com/aptos-labs/aptos-core/blob/main/SECURITY.md) for the full disclosure process.
