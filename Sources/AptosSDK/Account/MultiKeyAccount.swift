import Foundation

/// An M-of-N multi-key account.
///
/// Contains a `MultiKey` (the N public keys and threshold) and
/// the subset of signers that will actually sign transactions.
public struct MultiKeyAccount: AptosAccount {
    public let multiKey: MultiKey
    public let signers: [any AptosAccount]
    public let signerIndices: [Int]
    public let accountAddress: AccountAddress
    public let signingScheme: SigningScheme = .multiKey

    public var publicKey: any AccountPublicKey {
        multiKey.publicKeys.first!
    }

    /// Create a multi-key account.
    ///
    /// - Parameters:
    ///   - multiKey: The M-of-N multi-key containing all public keys and the threshold.
    ///   - signers: The accounts that will sign (must be at least `signaturesRequired`).
    ///   - signerIndices: The indices of each signer within `multiKey.publicKeys`.
    public init(
        multiKey: MultiKey,
        signers: [any AptosAccount],
        signerIndices: [Int]
    ) throws {
        guard signers.count == signerIndices.count else {
            throw AptosError.invalidArgument(
                "signers and signerIndices must have the same length"
            )
        }
        guard signers.count >= Int(multiKey.signaturesRequired) else {
            throw AptosError.invalidArgument(
                "Need at least \(multiKey.signaturesRequired) signers, got \(signers.count)"
            )
        }
        self.multiKey = multiKey
        self.signers = signers
        self.signerIndices = signerIndices
        self.accountAddress = multiKey.authKey().derivedAddress()
    }

    public func sign(message: Data) throws -> any AccountSignature {
        // Sign with each signer and construct a multi-key signature
        var indexedSigs: [(index: Int, signature: AnySignature)] = []
        for (signer, index) in zip(signers, signerIndices) {
            let sig = try signer.sign(message: message)
            // Wrap the signature in AnySignature based on the signer type
            let anySig: AnySignature
            if let edSig = sig as? Ed25519Signature {
                anySig = .ed25519(edSig)
            } else if let secpSig = sig as? Secp256k1Signature {
                anySig = .secp256k1(secpSig)
            } else {
                throw AptosError.cryptoError("Unsupported signature type in MultiKeyAccount")
            }
            indexedSigs.append((index: index, signature: anySig))
        }
        return MultiKeySignature.create(
            signatures: indexedSigs,
            totalKeys: multiKey.publicKeys.count
        )
    }

    public func signWithAuthenticator(message: Data) throws -> AccountAuthenticator {
        let sig = try sign(message: message) as! MultiKeySignature
        return .multiKey(publicKey: multiKey, signatures: sig)
    }
}
