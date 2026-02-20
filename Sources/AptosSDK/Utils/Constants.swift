import Foundation

/// SDK-wide constants and defaults.
public enum AptosConstants {
    /// SDK version string.
    public static let version = "0.1.0"

    /// Default maximum gas amount for transactions.
    public static let defaultMaxGasAmount: UInt64 = 200_000

    /// Default gas unit price.
    public static let defaultGasUnitPrice: UInt64 = 100

    /// Default transaction expiry in seconds from now.
    public static let defaultTxnExpirySecs: UInt64 = 20

    /// Default timeout for waiting for transaction confirmation (seconds).
    public static let defaultTxnTimeoutSecs: UInt64 = 20

    /// Polling interval for transaction wait (milliseconds).
    public static let waitForTxnPollIntervalMs: UInt64 = 200

    /// User-agent header value.
    public static let userAgent = "aptos-swift-sdk/\(version)"

    /// The APT coin type.
    public static let aptosCoin = "0x1::aptos_coin::AptosCoin"

    /// The fungible asset metadata address for APT.
    public static let aptosFAAddress = "0x000000000000000000000000000000000000000000000000000000000000000a"

    /// BCS MIME type for signed transaction submission.
    public static let bcsSignedTransactionMIME = "application/x.aptos.signed_transaction+bcs"

    /// BCS MIME type for general BCS content.
    public static let bcsMIME = "application/x-bcs"

    /// Default cache TTL for ABI lookups (seconds).
    public static let abiCacheTTL: TimeInterval = 300

    /// Default cache TTL for gas price estimates (seconds).
    public static let gasPriceCacheTTL: TimeInterval = 300

    /// Maximum entries in transaction worker history.
    public static let maxTransactionWorkerHistory = 10_000

    /// Eviction count when history limit is exceeded.
    public static let transactionWorkerEvictionCount = 1_000

    /// Maximum in-flight transactions for batch worker.
    public static let maximumInFlight = 100
}
