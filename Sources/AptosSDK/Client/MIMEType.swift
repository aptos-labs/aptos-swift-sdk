import Foundation

/// Content types used for Aptos API requests.
public enum MIMEType: String, Sendable {
    case json = "application/json"
    case bcs = "application/x-bcs"
    case bcsSignedTransaction = "application/x.aptos.signed_transaction+bcs"
    case bcsViewFunction = "application/x.aptos.view_function+bcs"
}
