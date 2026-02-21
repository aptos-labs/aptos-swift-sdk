# AptosWallet

A sample iOS wallet app demonstrating the Aptos Swift SDK.

## Features

- **Create Wallet** — Generate a new account with BIP-39 mnemonic
- **Import Wallet** — Restore from a recovery phrase
- **Check Balance** — View APT balance in real-time
- **Fund from Faucet** — Request devnet APT tokens
- **Send APT** — Transfer tokens to any address
- **Transaction History** — View recent account transactions
- **Secure Storage** — Mnemonic stored in iOS Keychain

## Requirements

- iOS 17.0+
- Xcode 16.0+
- Swift 6.0

## Getting Started

1. Open `AptosWallet.xcodeproj` in Xcode
2. The project uses a local package dependency pointing to the SDK root (`../../`)
3. Select an iOS Simulator and run

The app connects to **Aptos devnet** by default, which provides a faucet for free test tokens.

## Architecture

- **SwiftUI** with `@Observable` view models (iOS 17+)
- Single `WalletViewModel` manages all SDK interactions
- `KeychainService` wraps the Security framework for mnemonic persistence
- Three-tab layout: Wallet, Send, Settings

## SDK APIs Demonstrated

| Feature | SDK API |
|---------|---------|
| Account creation | `Mnemonic.generate()`, `Ed25519Account.fromMnemonic()` |
| Balance query | `client.coin.getBalance()` |
| Faucet funding | `client.faucet.fundAccount()` |
| Token transfer | `client.coin.transferAPT()` |
| Transaction history | `client.transaction.getAccountTransactions()` |
