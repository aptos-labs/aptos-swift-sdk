import Foundation

/// Manages account sequence numbers for parallel transaction submission.
///
/// Tracks local sequence numbers, synchronizes with on-chain state,
/// and provides monotonically increasing sequence numbers for
/// concurrent transaction building.
public actor AccountSequenceNumber {
    private let config: AptosConfig
    private let client: AptosHTTPClient
    private let address: AccountAddress

    private var currentNumber: UInt64?
    private var lastSynced: Date = .distantPast
    private let syncInterval: TimeInterval = 10

    public init(config: AptosConfig, client: AptosHTTPClient, address: AccountAddress) {
        self.config = config
        self.client = client
        self.address = address
    }

    /// Get the next sequence number, syncing with chain if needed.
    public func nextSequenceNumber() async throws -> UInt64 {
        if let current = currentNumber, Date().timeIntervalSince(lastSynced) < syncInterval {
            currentNumber = current + 1
            return current
        }

        // Sync with on-chain state
        let response: AptosResponse<AccountData> = try await client.get(
            path: "/accounts/\(address)",
            originMethod: "AccountSequenceNumber.sync"
        )
        guard let onChainSeq = UInt64(response.data.sequenceNumber) else {
            throw AptosError.internalError("Invalid sequence number: \(response.data.sequenceNumber)")
        }

        // Use whichever is higher: our local or on-chain
        let seq = max(onChainSeq, currentNumber ?? 0)
        currentNumber = seq + 1
        lastSynced = Date()
        return seq
    }

    /// Force sync with on-chain state.
    public func synchronize() async throws {
        let response: AptosResponse<AccountData> = try await client.get(
            path: "/accounts/\(address)",
            originMethod: "AccountSequenceNumber.synchronize"
        )
        guard let seq = UInt64(response.data.sequenceNumber) else {
            throw AptosError.internalError("Invalid sequence number: \(response.data.sequenceNumber)")
        }
        currentNumber = seq
        lastSynced = Date()
    }
}
