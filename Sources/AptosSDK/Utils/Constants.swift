import BigInt
import Foundation

/// SDK version string.
public let sdkVersion = "0.1.0"

// MARK: - Gas Defaults

public let defaultMaxGasAmount: UInt64 = 200_000
public let defaultTxnExpSecFromNow: UInt64 = 20
public let defaultTxnTimeoutSec: UInt64 = 20

// MARK: - Framework Addresses

public let aptosCoin = "0x1::aptos_coin::AptosCoin"
public let aptosFAAddress =
    "0x000000000000000000000000000000000000000000000000000000000000000a"

// MARK: - Signing Salts

public let rawTransactionSalt = "APTOS::RawTransaction"
public let rawTransactionWithDataSalt = "APTOS::RawTransactionWithData"
public let accountAbstractionSigningDataSalt = "APTOS::AASigningData"

// MARK: - BCS Limits

public let maxU8: UInt8 = .max
public let maxU16: UInt16 = .max
public let maxU32: UInt32 = .max
public let maxU64: UInt64 = .max
public let maxU128: BigUInt = (BigUInt(1) << 128) - 1
public let maxU256: BigUInt = (BigUInt(1) << 256) - 1

// MARK: - Cache

public let defaultCacheMaxSize = 1000
public let ledgerInfoCacheTTL: TimeInterval = 10
public let gasPriceCacheTTL: TimeInterval = 300
public let abiCacheTTL: TimeInterval = 300
public let cacheCleanupInterval: TimeInterval = 60

// MARK: - Transaction Worker

public let maxTransactionHistory = 10_000
public let transactionHistoryEvictionCount = 1_000
public let defaultMaximumInFlight = 100
public let defaultWorkerMaxWaitTime: TimeInterval = 30
public let defaultWorkerSleepTime: TimeInterval = 10

// MARK: - Indexer Sync

public let indexerSyncTimeout: TimeInterval = 3
public let indexerSyncPollingInterval: TimeInterval = 0.2

// MARK: - Pagination

public let defaultPageSize = 25
