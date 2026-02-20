import Foundation

/// Transaction wait timeout error.
public struct WaitForTransactionError: Error, Sendable {
    public let message: String
    public let lastSubmittedTransaction: TransactionResponse?

    public init(message: String, lastSubmittedTransaction: TransactionResponse? = nil) {
        self.message = message
        self.lastSubmittedTransaction = lastSubmittedTransaction
    }
}

extension WaitForTransactionError: LocalizedError {
    public var errorDescription: String? { message }
}

/// Failed transaction (committed but success=false).
public struct FailedTransactionError: Error, Sendable {
    public let transaction: CommittedTransactionResponse

    public var vmStatus: String { transaction.vmStatus }

    public init(transaction: CommittedTransactionResponse) {
        self.transaction = transaction
    }
}

extension FailedTransactionError: LocalizedError {
    public var errorDescription: String? {
        "Transaction failed with vm_status: \(vmStatus)"
    }
}
