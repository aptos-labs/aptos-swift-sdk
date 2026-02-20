import Foundation

/// Batch transaction processor using Swift structured concurrency.
///
/// Processes queued transactions in order, managing sequence numbers
/// and providing status updates via an async event stream.
///
/// ```swift
/// let worker = TransactionWorker(config: config, client: client, account: account)
/// let stream = worker.eventStream
///
/// worker.push(payload: InputEntryFunctionData(...))
/// worker.push(payload: InputEntryFunctionData(...))
/// await worker.start()
///
/// for await event in stream {
///     switch event {
///     case .transactionSent(let hash): print("Sent: \(hash)")
///     case .transactionExecuted(let hash): print("Executed: \(hash)")
///     case .transactionSendFailed(let error): print("Failed: \(error)")
///     case .transactionExecutionFailed(let error): print("Failed: \(error)")
///     case .executionFinish: print("Done")
///     }
/// }
/// ```
public actor TransactionWorker {
    /// Events emitted during batch processing.
    public enum Event: Sendable {
        case transactionSent(hash: String)
        case transactionSendFailed(Error)
        case transactionExecuted(hash: String)
        case transactionExecutionFailed(Error)
        case executionFinish
    }

    private let config: AptosConfig
    private let client: AptosHTTPClient
    private let account: any AptosAccount
    private let maximumInFlight: Int
    private let maxWaitTime: TimeInterval
    private let sleepTime: TimeInterval

    private var pendingPayloads: [(InputEntryFunctionData, TransactionOptions?)] = []
    private var isRunning = false
    private var continuation: AsyncStream<Event>.Continuation?

    /// The event stream for monitoring batch progress.
    public let eventStream: AsyncStream<Event>

    public init(
        config: AptosConfig,
        client: AptosHTTPClient,
        account: any AptosAccount,
        maximumInFlight: Int = defaultMaximumInFlight,
        maxWaitTime: TimeInterval = defaultWorkerMaxWaitTime,
        sleepTime: TimeInterval = defaultWorkerSleepTime
    ) {
        self.config = config
        self.client = client
        self.account = account
        self.maximumInFlight = maximumInFlight
        self.maxWaitTime = maxWaitTime
        self.sleepTime = sleepTime

        var cont: AsyncStream<Event>.Continuation?
        self.eventStream = AsyncStream { cont = $0 }
        self.continuation = cont
    }

    /// Enqueue a transaction payload for batch processing.
    public func push(payload: InputEntryFunctionData, options: TransactionOptions? = nil) {
        pendingPayloads.append((payload, options))
    }

    /// Start processing enqueued transactions.
    public func start() async {
        guard !isRunning else { return }
        isRunning = true

        let builder = TransactionBuilder(config: config, client: client)
        let transactionAPI = TransactionAPI(config: config, client: client)
        var inFlightHashes: [String] = []

        while !pendingPayloads.isEmpty {
            // Wait if too many in-flight
            while inFlightHashes.count >= maximumInFlight {
                try? await Task.sleep(nanoseconds: UInt64(sleepTime * 1_000_000_000))
                // Check for completed
                var remaining: [String] = []
                for hash in inFlightHashes {
                    do {
                        let txn = try await transactionAPI.getTransactionByHash(hash)
                        if txn.isPending {
                            remaining.append(hash)
                        } else {
                            if txn.success == true {
                                continuation?.yield(.transactionExecuted(hash: hash))
                            } else {
                                continuation?.yield(.transactionExecutionFailed(
                                    AptosError.internalError("Transaction \(hash) failed: \(txn.vmStatus ?? "unknown")")
                                ))
                            }
                        }
                    } catch {
                        remaining.append(hash)
                    }
                }
                inFlightHashes = remaining
            }

            let (payload, options) = pendingPayloads.removeFirst()

            do {
                let txn = try await builder.buildSimple(
                    sender: account.accountAddress,
                    data: payload,
                    options: options
                )
                let pending = try await transactionAPI.signAndSubmitTransaction(
                    signer: account,
                    transaction: .simple(txn)
                )
                inFlightHashes.append(pending.hash)
                continuation?.yield(.transactionSent(hash: pending.hash))
            } catch {
                continuation?.yield(.transactionSendFailed(error))
            }
        }

        // Wait for remaining in-flight transactions
        for hash in inFlightHashes {
            do {
                let committed = try await transactionAPI.waitForTransaction(
                    hash: hash,
                    options: WaitForTransactionOptions(timeoutSecs: UInt64(maxWaitTime))
                )
                if committed.success {
                    continuation?.yield(.transactionExecuted(hash: hash))
                } else {
                    continuation?.yield(.transactionExecutionFailed(
                        FailedTransactionError(transaction: committed)
                    ))
                }
            } catch {
                continuation?.yield(.transactionExecutionFailed(error))
            }
        }

        continuation?.yield(.executionFinish)
        continuation?.finish()
        isRunning = false
    }
}
