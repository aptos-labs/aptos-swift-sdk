import CryptoKit
import Foundation

// MARK: - WebAuthnUtils

/// Minimal WebAuthn helpers for parsing and verifying WebAuthn signatures.
public enum WebAuthnUtils {
    // MARK: - ClientData

    /// Parsed clientDataJSON fields.
    public struct ClientData: Sendable, Equatable {
        /// The decoded challenge bytes.
        public let challenge: Data
        /// The origin (e.g., "https://example.com").
        public let origin: String
        /// The type (e.g., "webauthn.get").
        public let type: String
    }

    // MARK: - Parsing

    /// Parses a WebAuthn clientDataJSON blob.
    ///
    /// Extracts `type`, `challenge` (base64url-decoded), and `origin`.
    public static func parseClientDataJSON(_ data: Data) throws -> ClientData {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AptosError.parse(.invalidHex("Failed to parse clientDataJSON"))
        }
        guard let type = json["type"] as? String else {
            throw AptosError.parse(.invalidHex("Missing 'type' in clientDataJSON"))
        }
        guard let challengeStr = json["challenge"] as? String else {
            throw AptosError.parse(.invalidHex("Missing 'challenge' in clientDataJSON"))
        }
        guard let origin = json["origin"] as? String else {
            throw AptosError.parse(.invalidHex("Missing 'origin' in clientDataJSON"))
        }

        // base64url decode the challenge
        var base64 = challengeStr
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while !base64.count.isMultiple(of: 4) {
            base64.append("=")
        }
        guard let challengeData = Data(base64Encoded: base64) else {
            throw AptosError.parse(.invalidHex("Invalid base64url challenge in clientDataJSON"))
        }

        return ClientData(challenge: challengeData, origin: origin, type: type)
    }

    // MARK: - Verification

    /// Verifies a WebAuthn signature using P-256.
    ///
    /// The signed message is `authenticatorData || SHA-256(clientDataJSON)`,
    /// which ECDSA-SHA256 then hashes internally before verifying.
    public static func verifyWebAuthnSignature(
        publicKey: Secp256r1PublicKey,
        signature: Secp256r1Signature,
        authenticatorData: Data,
        clientDataJSON: Data
    ) -> Bool {
        let clientDataHash = Data(CryptoKit.SHA256.hash(data: clientDataJSON))
        var message = authenticatorData
        message.append(clientDataHash)

        guard let key = try? P256.Signing.PublicKey(x963Representation: publicKey.data) else {
            return false
        }
        guard let ecdsaSig = try? P256.Signing.ECDSASignature(rawRepresentation: signature.data) else {
            return false
        }
        return key.isValidSignature(ecdsaSig, for: message)
    }
}
