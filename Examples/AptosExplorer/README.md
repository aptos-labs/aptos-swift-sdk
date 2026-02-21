# AptosExplorer

A sample iOS + macOS developer tools app demonstrating the Aptos Swift SDK.

## Features

- **Ledger Info** — View chain ID, epoch, version, block height, gas estimates with auto-refresh
- **Account Inspector** — Look up any account's data, balance, resources, and modules
- **Transaction Lookup** — Search by hash or browse recent global transactions
- **Block Explorer** — Navigate blocks by height with previous/next buttons
- **View Function** — Execute Move view functions with dynamic arguments and presets
- **Network Settings** — Switch between Testnet, Mainnet, and Devnet

## Requirements

- iOS 17.0+ / macOS 14.0+
- Xcode 16.0+
- Swift 6.0

## Getting Started

1. Open `AptosExplorer.xcodeproj` in Xcode
2. The project uses a local package dependency pointing to the SDK root (`../../`)
3. Select an iOS Simulator or "My Mac" and run

The app defaults to **Aptos testnet**. Use Network Settings to switch networks.

## Architecture

- **SwiftUI** with `NavigationSplitView` for multiplatform sidebar layout
- `AppState` manages network selection and client lifecycle
- Each feature has its own `@Observable` view model
- Views reset state on network change via `.id(selectedNetwork)`
- `#if os(iOS)` used only for keyboard type differences

## SDK APIs Demonstrated

| Feature | SDK API |
|---------|---------|
| Ledger info | `client.general.getLedgerInfo()` |
| Gas estimation | `client.general.estimateGasPrice()` |
| Account data | `client.account.getAccount()` |
| Account resources | `client.account.getAccountResources()` |
| Account modules | `client.account.getAccountModules()` |
| APT balance | `client.coin.getBalance()` |
| Transaction by hash | `client.transaction.getTransactionByHash()` |
| Recent transactions | `client.transaction.getTransactions()` |
| Block by height | `client.general.getBlockByHeight()` |
| View functions | `client.view.view()` |
