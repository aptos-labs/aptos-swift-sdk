import Foundation

// MARK: - MultiEd25519Account

/// A legacy multi-Ed25519 account supporting M-of-N Ed25519 signatures.
///
/// Supports two modes:
/// - **Local signing**: Provide private keys that sign directly.
/// - **Pre-collected**: Provide externally-collected signatures and their indices.
public struct MultiEd25519Account: Sendable {
    /// The multi-Ed25519 public key.
    public let multiKey: MultiEd25519PublicKey

    /// The account address.
    public let accountAddress: AccountAddress

    /// Internal signing mode.
    private enum SignMode: Sendable {
        case local(signers: [Ed25519PrivateKey], signerIndices: [Int])
        case preCollected(signatures: [Ed25519Signature], signerIndices: [Int])
    }

    private let signMode: SignMode

    /// Creates a multi-Ed25519 account for local signing.
    ///
    /// - Parameters:
    ///   - multiKey: The multi-Ed25519 public key.
    ///   - signers: The private keys that will sign transactions.
    ///   - signerIndices: The indices in `multiKey.publicKeys` that correspond to the signers.
    public init(
        multiKey: MultiEd25519PublicKey,
        signers: [Ed25519PrivateKey],
        signerIndices: [Int]
    ) throws {
        guard signers.count == signerIndices.count else {
            throw AptosError.multiSignature(.insufficientSignatures(
                required: signerIndices.count, provided: signers.count
            ))
        }
        guard signers.count >= Int(multiKey.threshold) else {
            throw AptosError.multiSignature(.insufficientSignatures(
                required: Int(multiKey.threshold), provided: signers.count
            ))
        }
        try Self.validateIndices(signerIndices, totalKeys: multiKey.publicKeys.count)
        self.multiKey = multiKey
        signMode = .local(signers: signers, signerIndices: signerIndices)
        let authKey = try AuthenticationKey.fromMultiEd25519(publicKey: multiKey)
        accountAddress = authKey.accountAddress()
    }

    /// Creates a multi-Ed25519 account from pre-collected signatures.
    ///
    /// - Parameters:
    ///   - multiKey: The multi-Ed25519 public key.
    ///   - signatures: The externally-collected signatures.
    ///   - signerIndices: The indices in `multiKey.publicKeys` that produced the signatures.
    public init(
        multiKey: MultiEd25519PublicKey,
        signatures: [Ed25519Signature],
        signerIndices: [Int]
    ) throws {
        guard signatures.count == signerIndices.count else {
            throw AptosError.multiSignature(.insufficientSignatures(
                required: signerIndices.count, provided: signatures.count
            ))
        }
        guard signatures.count >= Int(multiKey.threshold) else {
            throw AptosError.multiSignature(.insufficientSignatures(
                required: Int(multiKey.threshold), provided: signatures.count
            ))
        }
        try Self.validateIndices(signerIndices, totalKeys: multiKey.publicKeys.count)
        self.multiKey = multiKey
        signMode = .preCollected(signatures: signatures, signerIndices: signerIndices)
        let authKey = try AuthenticationKey.fromMultiEd25519(publicKey: multiKey)
        accountAddress = authKey.accountAddress()
    }

    /// Signs a message and produces a MultiEd25519Signature.
    public func signMultiEd25519(message: Data) throws -> MultiEd25519Signature {
        switch signMode {
        case let .local(signers, signerIndices):
            var indexedSigs: [(index: Int, signature: Ed25519Signature)] = []
            for (i, signer) in signers.enumerated() {
                let sig = try signer.sign(message)
                indexedSigs.append((index: signerIndices[i], signature: sig))
            }
            return try MultiEd25519Signature.fromSignaturesWithIndices(
                signatures: indexedSigs,
                totalKeys: multiKey.publicKeys.count
            )
        case let .preCollected(signatures, signerIndices):
            var indexedSigs: [(index: Int, signature: Ed25519Signature)] = []
            for (i, sig) in signatures.enumerated() {
                indexedSigs.append((index: signerIndices[i], signature: sig))
            }
            return try MultiEd25519Signature.fromSignaturesWithIndices(
                signatures: indexedSigs,
                totalKeys: multiKey.publicKeys.count
            )
        }
    }

    /// Validates signer indices: no duplicates, all in range.
    private static func validateIndices(_ indices: [Int], totalKeys: Int) throws {
        var seen = Set<Int>()
        for index in indices {
            guard index >= 0, index < totalKeys else {
                throw AptosError.multiSignature(.invalidSignerIndex(
                    index: index, totalKeys: totalKeys
                ))
            }
            guard seen.insert(index).inserted else {
                throw AptosError.multiSignature(.duplicateSignerIndex(index: index))
            }
        }
    }
}

// MARK: AptosAccount

extension MultiEd25519Account: AptosAccount {
    public var signingScheme: SigningScheme {
        .multiEd25519
    }

    public var publicKeyBytes: Data {
        (try? bcsToBytes(multiKey)) ?? Data()
    }

    public func sign(message: Data) throws -> AnySignature {
        let multiSig = try signMultiEd25519(message: message)
        guard let first = multiSig.signatures.first else {
            throw AptosError.multiSignature(.insufficientSignatures(required: 1, provided: 0))
        }
        return .ed25519(first)
    }

    public func signWithAuthenticator(message: Data) throws -> AccountAuthenticator {
        let multiSig = try signMultiEd25519(message: message)
        return .multiEd25519(publicKey: multiKey, signature: multiSig)
    }

    public func authenticationKey() throws -> AuthenticationKey {
        try AuthenticationKey.fromMultiEd25519(publicKey: multiKey)
    }
}
