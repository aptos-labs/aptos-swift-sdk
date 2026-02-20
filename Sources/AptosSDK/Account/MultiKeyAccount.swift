import Foundation

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
            throw AptosError.invalidArgument("signers and signerIndices must have the same count")
        }
        guard signers.count >= Int(multiKey.signaturesRequired) else {
            throw AptosError.invalidArgument(
                "Need at least \(multiKey.signaturesRequired) signers, got \(signers.count)")
        }
        self.multiKey = multiKey
        self.signers = signers
        self.signerIndices = signerIndices
        let authKey = try AuthenticationKey.fromMultiKey(multiKey: multiKey)
        self.accountAddress = authKey.accountAddress()
    }

    /// Signs a message with all signers and produces a MultiKeySignature.
    public func sign(message: Data) throws -> MultiKeySignature {
        var indexedSigs: [(index: Int, signature: AnySignature)] = []
        for (i, signer) in signers.enumerated() {
            let sig = try signer.sign(message: message)
            indexedSigs.append((index: signerIndices[i], signature: sig))
        }
        return MultiKeySignature.fromSignaturesWithIndices(
            signatures: indexedSigs,
            totalKeys: multiKey.publicKeys.count
        )
    }
}

extension MultiKeyAccount: AptosAccount {
    public var signingScheme: SigningScheme { .multiKey }

    public func sign(message: Data) throws -> AnySignature {
        // MultiKey returns multiple signatures, so we wrap in the first one
        // This shouldn't normally be called directly
        let multiSig: MultiKeySignature = try sign(message: message)
        return multiSig.signatures.first!
    }

    public func signWithAuthenticator(message: Data) throws -> AccountAuthenticator {
        let multiSig: MultiKeySignature = try sign(message: message)
        return .multiKey(publicKey: multiKey, signature: multiSig)
    }

    public func authenticationKey() throws -> AuthenticationKey {
        try AuthenticationKey.fromMultiKey(multiKey: multiKey)
    }
}
