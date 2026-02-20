import Foundation

/// Utilities for serializing/deserializing accounts.
public enum AccountUtils {
    /// Serialize an account to bytes.
    ///
    /// Format: `[SigningScheme as ULEB128] [AccountAddress (32 bytes)] [Scheme-specific data]`
    public static func toBytes(_ account: any AptosAccount) throws -> Data {
        var serializer = Serializer()
        serializer.serializeU32AsUleb128(UInt32(account.signingScheme.rawValue))
        account.accountAddress.serialize(to: &serializer)

        switch account.signingScheme {
        case .ed25519:
            guard let ed = account as? Ed25519Account else {
                throw AptosError.serializationError("Expected Ed25519Account")
            }
            serializer.serializeBytes(ed.privateKey.data)

        case .singleKey:
            guard let sk = account as? SingleKeyAccount else {
                throw AptosError.serializationError("Expected SingleKeyAccount")
            }
            sk.anyPublicKey.serialize(to: &serializer)

        case .multiKey:
            guard let mk = account as? MultiKeyAccount else {
                throw AptosError.serializationError("Expected MultiKeyAccount")
            }
            mk.multiKey.serialize(to: &serializer)
            serializer.serializeU32AsUleb128(UInt32(mk.signers.count))
            for signer in mk.signers {
                let signerBytes = try AccountUtils.toBytes(signer)
                serializer.serializeBytes(signerBytes)
            }

        case .multiEd25519, .abstraction:
            throw AptosError.serializationError(
                "Serialization not supported for scheme: \(account.signingScheme)"
            )
        }

        return serializer.output()
    }

    /// Serialize an account to a hex string with `0x` prefix.
    public static func toHexString(_ account: any AptosAccount) throws -> String {
        Hex.encode(try toBytes(account))
    }

    /// Deserialize an account from a hex string.
    public static func fromHex(_ hex: String) throws -> any AptosAccount {
        let data = try Hex.decode(hex)
        return try fromBytes(data)
    }

    /// Deserialize an account from bytes.
    public static func fromBytes(_ bytes: Data) throws -> any AptosAccount {
        var deserializer = Deserializer(data: bytes)
        let schemeRaw = try deserializer.deserializeUleb128()
        guard let scheme = SigningScheme(rawValue: UInt8(schemeRaw)) else {
            throw AptosError.deserializationError("Unknown signing scheme: \(schemeRaw)")
        }
        let address = try AccountAddress.deserialize(from: &deserializer)

        switch scheme {
        case .ed25519:
            let keyBytes = try deserializer.deserializeBytes()
            let privateKey = try Ed25519PrivateKey(data: keyBytes)
            return Ed25519Account(privateKey: privateKey, address: address)

        case .singleKey:
            let anyKey = try AnyPublicKey.deserialize(from: &deserializer)
            switch anyKey {
            case .ed25519:
                // We need the private key to reconstruct - stored after the public key variant
                let privBytes = try deserializer.deserializeBytes()
                let privateKey = try Ed25519PrivateKey(data: privBytes)
                return SingleKeyAccount(privateKey: privateKey, address: address)
            case .secp256k1:
                let privBytes = try deserializer.deserializeBytes()
                let privateKey = try Secp256k1PrivateKey(privBytes)
                return SingleKeyAccount(privateKey: privateKey)
            default:
                throw AptosError.deserializationError(
                    "Cannot deserialize SingleKeyAccount with variant: \(anyKey.variantIndex)"
                )
            }

        default:
            throw AptosError.deserializationError(
                "Account deserialization not supported for scheme: \(scheme)"
            )
        }
    }
}
