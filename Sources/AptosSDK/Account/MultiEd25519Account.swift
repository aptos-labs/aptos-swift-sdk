import Foundation

/// A legacy M-of-N Ed25519 multi-sig account.
public struct MultiEd25519Account: AptosAccount {
    public let multiPublicKey: MultiEd25519PublicKey
    public let privateKeys: [Ed25519PrivateKey]
    public let signerIndices: [Int]
    public let accountAddress: AccountAddress
    public let signingScheme: SigningScheme = .multiEd25519

    public var publicKey: any AccountPublicKey {
        multiPublicKey
    }

    public init(
        publicKey: MultiEd25519PublicKey,
        privateKeys: [Ed25519PrivateKey],
        signerIndices: [Int]
    ) throws {
        guard privateKeys.count == signerIndices.count else {
            throw AptosError.invalidArgument("privateKeys and signerIndices must have same length")
        }
        guard privateKeys.count >= Int(publicKey.threshold) else {
            throw AptosError.invalidArgument(
                "Need at least \(publicKey.threshold) private keys, got \(privateKeys.count)"
            )
        }
        self.multiPublicKey = publicKey
        self.privateKeys = privateKeys
        self.signerIndices = signerIndices
        let authKey = AuthenticationKey.fromPublicKeyBytes(publicKey.data, scheme: .multiEd25519)
        self.accountAddress = authKey.derivedAddress()
    }

    public func sign(message: Data) throws -> any AccountSignature {
        var sigs: [Ed25519Signature] = []
        for key in privateKeys {
            sigs.append(try key.sign(message: message))
        }
        // Build 4-byte bitmap
        var bitmapBytes = Data(repeating: 0, count: 4)
        for index in signerIndices {
            let byteIndex = index / 8
            let bitIndex = 7 - (index % 8)
            if byteIndex < 4 {
                bitmapBytes[byteIndex] |= (1 << bitIndex)
            }
        }
        return MultiEd25519Signature(signatures: sigs, bitmap: bitmapBytes)
    }

    public func signWithAuthenticator(message: Data) throws -> AccountAuthenticator {
        let sig = try sign(message: message) as! MultiEd25519Signature
        return .multiEd25519(publicKey: multiPublicKey, signature: sig)
    }
}
