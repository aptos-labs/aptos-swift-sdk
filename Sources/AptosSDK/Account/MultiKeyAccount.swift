import Foundation

// MARK: - MultiKeyAccount

/// A multi-key account supporting M-of-N signatures with mixed key types.
public struct MultiKeyAccount: Sendable {
    /// The multi-key public key.
    public let multiKey: MultiKey

    /// The individual signer accounts.
    public let signers: [any AptosAccount]

    /// The indices in the MultiKey.publicKeys that correspond to the signers.
    public let signerIndices: [Int]

    /// The account address.
    public let accountAddress: AccountAddress

    /// Creates a multi-key account.
    public init(multiKey: MultiKey, signers: [any AptosAccount], signerIndices: [Int]) throws {
        guard signers.count == signerIndices.count else {
            throw AptosError.multiSignature(.insufficientSignatures(
                required: signerIndices.count, provided: signers.count
            ))
        }
        guard signers.count >= Int(multiKey.signaturesRequired) else {
            throw AptosError.multiSignature(.insufficientSignatures(
                required: Int(multiKey.signaturesRequired), provided: signers.count
            ))
        }
        try Self.validateIndices(signerIndices, totalKeys: multiKey.publicKeys.count)
        self.multiKey = multiKey
        self.signers = signers
        self.signerIndices = signerIndices
        let authKey = try AuthenticationKey.fromMultiKey(multiKey: multiKey)
        accountAddress = authKey.accountAddress()
    }

    /// Signs a message with all signers and produces a MultiKeySignature.
    public func sign(message: Data) throws -> MultiKeySignature {
        var indexedSigs: [(index: Int, signature: AnySignature)] = []
        for (i, signer) in signers.enumerated() {
            let sig = try signer.sign(message: message)
            indexedSigs.append((index: signerIndices[i], signature: sig))
        }
        return try MultiKeySignature.validatedFromSignaturesWithIndices(
            signatures: indexedSigs,
            totalKeys: multiKey.publicKeys.count
        )
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

extension MultiKeyAccount: AptosAccount {
    public var signingScheme: SigningScheme {
        .multiKey
    }

    public var publicKeyBytes: Data {
        (try? bcsToBytes(multiKey)) ?? Data()
    }

    public func sign(message: Data) throws -> AnySignature {
        // MultiKey returns multiple signatures, so we wrap in the first one
        // This shouldn't normally be called directly
        let multiSig: MultiKeySignature = try sign(message: message)
        guard let first = multiSig.signatures.first else {
            throw AptosError.multiSignature(.insufficientSignatures(required: 1, provided: 0))
        }
        return first
    }

    public func signWithAuthenticator(message: Data) throws -> AccountAuthenticator {
        let multiSig: MultiKeySignature = try sign(message: message)
        return .multiKey(publicKey: multiKey, signature: multiSig)
    }

    public func authenticationKey() throws -> AuthenticationKey {
        try AuthenticationKey.fromMultiKey(multiKey: multiKey)
    }
}
